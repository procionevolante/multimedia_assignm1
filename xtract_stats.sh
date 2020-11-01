#!/bin/sh

if [ $# -ne 1 ]; then
	echo "USAGE: $0 [youtube video ID]" >&2
	exit 1
fi

video_id="$1"
cap_file="${video_id}-dsb.pcapng"

# extracting only info we need from captured file
tmp="$(tshark -r "$cap_file" -2R http -T fields \
	-e frame.time_relative \
	-e ip.dst \
	-e ipv6.dst \
	-e http.request.uri.path \
	-e http.response.code | tr -s '\t')"

# for each line, compute the country where that IP is from (tshark can't do it)
while read time ip reqres; do
	if [ -z "$(printf "$ip"| grep :)" ]; then
		# ipv4 address
		country="$(geoiplookup $ip | grep 'Country Edition' | tr -d ' ' | cut -d: -f2 | cut -c1,2)"
	else
		# ipv6 address
		country="$(geoiplookup6 $ip | grep 'Country V6 Edition' | tr -d ' ' | cut -d: -f2 | cut -c1,2)"
	fi
	info="$(printf '%s\n%s\t%s\t%s\t%s' "$info" "$time" "$ip" "$country" "$reqres")"
done << EOF
$tmp
EOF
unset tmp

# saving file also for further human inspection
info="$(echo "$info" | tail -n +2 | tee "${video_id}.xtract-log")"

#  calculating what we want of the video...

#video_id="$(echo "$1" | tr '?&' '\n' | grep -E '^v=' | cut -d= -f2)"
# counting how many redirects to get the video (redirect = response HTTP code is 300-399)
#n_redir="$(echo "$info" | awk 'BEGIN{c=0} $4 ~ /^3..$/{ c++ } END{ print(c) }')"
n_redir="$(grep '302 Found' <"$video_id".ytdl-log | wc -l)"
# total cache time (from getting manifest to making request to server with video)
# we take the timestamp of the packet containing info about video qualities available
# (expected to be the packet before GET /videoplayback)
manifest_time="$(echo "$info" | grep -B 1 '/videoplayback' | head -n 1 | cut -f 1)"
# playback time: when the client requests the video to the server actually storing it
playback_time="$(echo "$info" | grep '/videoplayback' | tail -n 1 | cut -f 1)"
if [ -z "$manifest_time" -o -z "$playback_time" ]; then
	echo "$video_id : times couldn't be recovered. check manually" >&2
	manifest_time=0
	playback_time=0
fi

#echo "$manifest_time -> $playback_time"
cache_time_ms="$(echo "($playback_time - $manifest_time)*1000" | bc | cut -d. -f1)"
# visited countries during cache-server hopping
countries="$(echo -n "$info" | grep / | cut -f 3 | tail -n $(($n_redir + 1)) | tr '\n' ' ')"
# IP of first-visited cache server
first_cache="$(echo -n "$info" | grep / | tail -n $(($n_redir + 1)) | head -n 1 | cut -f 2)"
# IP of video-storing server
last_cache="$(echo -n "$info" | grep / | tail -n 1 | cut -f 2)"

#  ...and printing it
printf '%s %1d %4d %s %s %s\n'  "$video_id" "$n_redir" "$cache_time_ms" "$first_cache" "$last_cache" "$countries"

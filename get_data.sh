#!/bin/sh

# get statistics of one (or more) yt video(s)
# requires these packages:
# * youtube-dl
# * tshark (comes with wireshark)
# * bc (should be available on evey unix-like computer)

if [ $# -ne 1 ]; then
	echo "USAGE: $0 [youtube_url]"
	exit 1
fi

# interesting how -q flag implies "don't write to stdout if is redirected" but
# only if we're saving the TLS keys... Solved using --no-progress instead
YTFLAGS="-f best --no-progress -r 50K --print-traffic -o /dev/null --no-cache-dir"
# for how many seconds should we capture packets?
capture_time_s=10
video_id="$(echo "$1" | tr '?&' '\n' | egrep '^v=' | cut -d= -f2)"

echo "getting data for '$video_id'"

# packet capture automatically stops after specified time
tshark -Qw capture.pcapng --autostop duration:$capture_time_s >/dev/null &
tshark_pid=$!

# wait for start...
sleep 1

SSLKEYLOGFILE=./keylog.txt youtube-dlc $YTFLAGS "$@" > http.log 2> ytdl.err &
ytdownload_pid=$!

wait $tshark_pid

kill $ytdownload_pid
if [ "$(wc -l < ytdl.err)" -gt 0 ]; then
	echo there has been some error while executing youtube-dl: >&2
	cat ytdl.err >&2
	exit 1
fi

mv http.log "${video_id}.ytdl-log"

# embedding the TLS keys into the capture log (so we can decrypt it)
editcap --inject-secrets tls,keylog.txt capture.pcapng "${video_id}-dsb.pcapng"
rm capture.pcapng keylog.txt

echo "got data for '$video_id'."

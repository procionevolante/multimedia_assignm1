#!/bin/bash
basedir="$(dirname "$0")"
for v in $(cat urls); do
	cnt=0
	until "$basedir/get_data.sh" "$v"; do
		cnt=$((cnt+1))
		if [ $cnt -eq 5 ]; then
			echo max number of retries reached. Skipping video
			break
		else
			echo retrying...
		fi
	done
done

printf '' > errors
printf '' > stats
for video_id in $(basename -s .ytdl-log *.ytdl-log); do
	./xtract_stats.sh "$video_id" >> stats 2>> errors
done

output_dir="data_$(date '+%Y-%m-%d')"
mkdir "$output_dir"
mv errors stats *.ytdl-log *.xtract-log *-dsb.pcapng "./$output_dir"

exit 0

#------------
# this script require pytomo. get it with:
# $ git clone https://version.aalto.fi/gitlab/vikbere2/pytomo.git
#pytomo="$HOME/src/pytomo/start_crawl.py"
# pytomo doesn't work and making it work is nonsense because what we have
# to do can be "easily" done via some other stuff (if you knew..)

declare -A urls

checkFileExists(){
	if ! [ -f "$1" ]; then
		echo "'$1' file nonexistent. exiting" >&2
		exit 1
	fi
}

for v in t m b; do
	checkFileExists "urls_$v"
	urls+=( [$v]="$(cat "urls_$v")" )
done

cd "$(dirname "$pytomo")"
for v in t m b; do
	echo analyzing with views=$v
	# explicitly running with python2 because it's an old script and python3
	# would be called otherwise. Either we do this or change the shebang
	python2 "$pytomo" -p 0 -x -P 0 -R '--http-proxy=' --provider=fuffa ${urls[$v]} 
	exit
done

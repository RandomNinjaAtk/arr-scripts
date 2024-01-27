#!/usr/bin/with-contenv bash
ScriptVersion="1.7"
scriptName="Audiobook"

#### Import Settings
source /config/extended.conf

log () {
  m_time=`date "+%F %T"`
  echo $m_time" :: $scriptName :: $ScriptVersion :: "$1
}

if [ -z $allowM4b ]; then
	allowM4b=true
fi

if [ -z $allowMp3 ]; then
	allowMp3=true
fi

set -e
set -o pipefail

touch "/config/scripts/audiobook.txt"
exec &> >(tee -a "/config/scripts/audiobook.txt")


SECONDS=0
log "Processing $1"
m4bCount=$(find "$1" -type f -iname "*.m4b" | wc -l)
if [ $m4bCount -gt 1 ]; then
	log "ERROR: More than 1 M4B file found, performing cleanup..."
	find "$1" -type f -iname "m4b" -delete
else
	log "Searching for audiobook (m4b) files in completed download..."
	if [ $m4bCount -gt 0 ]; then
		log "$m4bCount M4B files found, removing non m4b files..."
		find "$1" -type f -not -iname "*.m4b" -delete
		find "$1" -mindepth 2 -type f -exec mv "{}" "$1"/ \;
		find "$1" -mindepth 1 -type d -delete
	else
		log "None found..."
	fi
 fi

mp4Count=$(find "$1" -type f -iname "*.m4b.mp4" | wc -l)
if [ $mp4Count -gt 1 ]; then
	log "ERROR: More than 1 MP4 file found, performing cleanup..."
	find "$1" -type f -iname "*.mp4" -delete
else
	log "Searching for audiobook (m4b.mp4) files in completed download..."
	if [ $mp4Count -gt 0 ]; then
		log "$mp4Count M4B (m4b.mp4) files found, removing non m4b files..."
		find "$1" -type f -not -iname "*.m4b.mp4" -delete
		find "$1" -mindepth 2 -type f -exec mv "{}" "$1"/ \;
		find "$1" -mindepth 1 -type d -delete
		log "Renaming m4b.mp4 files to m4b..."
		count=0
		fileCount=$(find "$1" -type f -iname "*.m4b.mp4"| wc -l)
		find "$1" -type f -iname "*.m4b.mp4" -print0 | while IFS= read -r -d '' file; do
			count=$(($count+1))
			baseFileName="${file%.*}"
			fileName="$(basename "$file")"
			extension="${fileName##*.}"
			log "$count of $fileCount :: Processing $fileName"
			if [ -f "$file" ]; then
				mv "$file" "$1/${fileName%.*}"
			fi
		done
		log "All files renamed"
	else
		log "None found..."
	fi
fi

mp3Count=$(find "$1" -type f -iname "*.mp3" | wc -l)
if [ $mp3Count -gt 1 ]; then
	log "ERROR: More than 1 MP3 file found, performing cleanup..."
	find "$1" -type f -iname "*.mp3" -delete
else
	log "Searching for audiobook (mp3) files in completed download..."
	if [ $mp3Count -gt 0 ]; then
		log "$mp3Count MP3 files found, removing non mp3 files..."
		find "$1" -type f -not -iname "*.mp3" -delete
		find "$1" -mindepth 2 -type f -exec mv "{}" "$1"/ \;
		find "$1" -mindepth 1 -type d -delete
	else
		log "None found..."
	fi
 fi

error="false"
bookfound="false"
m4bCount=$(find "$1" -type f -iname "*.m4b" | wc -l)
mp3Count=$(find "$1" -type f -iname "*.mp3" | wc -l)
#log "$m4bCount m4bs found :: $mp3Count mp3s found"
if [ "$bookfound" == "false" ]; then
	if [ $m4bCount -eq 0 ]; then
		error="true"
	else
		bookfound="true"
		error="false"
	fi
fi

if [ "$bookfound" == "false" ]; then
	if [ $mp3Count -eq 0 ]; then
		error="true"
	else
		bookfound="true"
		error="false"
	fi
fi

if [ "$allowM4b" != "true" ]; then
	if [ $allowM4b -gt 0 ]; then
 		log "M4B's disabled via config file, performing cleanup..."
 		rm "$1"/*
 		error="true"
	fi
fi

if [ "$allowMp3" != "true" ]; then
	if [ $mp3Count -gt 0 ]; then
		log "MP3's disabled via config file, performing cleanup..."
 		rm "$1"/*
 		error="true"
	fi
fi

if [ "$error" == "true" ]; then
	echo "ERROR: No audiobook files found" && exit 1
fi

chmod 777 "$1"
chmod 666 "$1"/*
duration=$SECONDS
echo "Post Processing Completed in $(($duration / 60 )) minutes and $(($duration % 60 )) seconds!"
exit

#!/usr/bin/with-contenv bash
ScriptVersion="0.5"
scriptName="Audiobook"

#### Import Settings
source /config/extended.conf

log () {
  m_time=`date "+%F %T"`
  echo $m_time" :: $scriptName :: $ScriptVersion :: "$1
}


set -e
set -o pipefail

touch "/config/scripts/audiobook.txt"
exec &> >(tee -a "/config/scripts/audiobook.txt")


SECONDS=0


log "Searching for audiobook (m4b) files in \"$1\"..."
if [ $(find "$1" -type f -iname "*.m4b" | wc -l) -gt 0 ]; then
	log "M4B files found, removing non m4b files..."
	find "$1" -type f -not -iname "*.m4b" -delete
	find "$1" -mindepth 2 -type f -exec mv "{}" "$1"/ \;
	find "$1" -mindepth 1 -type d -delete
fi

if [ $(find "$1" -type f -iname "*.m4b.mp4" | wc -l) -gt 0 ]; then
	log "M4B (m4b.mp4) files found, removing non m4b files..."
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
fi

if [ $(find "$1" -type f -iname "*.m4b" | wc -l) -eq 0 ]; then
	echo "ERROR: NO audiobook files found (M4B)" && exit 1
fi

chmod 777 "$1"
chmod 666 "$1"/*
duration=$SECONDS
echo "Post Processing Completed in $(($duration / 60 )) minutes and $(($duration % 60 )) seconds!"
exit

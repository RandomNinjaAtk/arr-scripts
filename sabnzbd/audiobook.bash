#!/usr/bin/with-contenv bash
ScriptVersion="0.2"
scriptName="Audiobook"

#### Import Settings
source /config/extended.conf

log () {
  m_time=`date "+%F %T"`
  echo $m_time" :: $scriptName :: $scriptVersion :: "$1
}


set -e
set -o pipefail

touch "/config/scripts/audiobook.txt"
exec &> >(tee -a "/config/scripts/audiobook.txt")

clean () {
		log "Searching for audiobook (m4b) files..."
		if [ $(find "$1" -type f -iname "*.m4b" | wc -l) -gt 0 ]; then
			log "M4B files found, removing non m4b files..."
			find "$1" -type f -not -iname "*.m4b" -delete
			find "$1" -mindepth 2 -type f -exec mv "{}" "$1"/ \;
			find "$1" -mindepth 1 -type d -delete
		else
			echo "ERROR: NO audiobook files found (M4B)" && exit 1
		fi
}

clean
exit

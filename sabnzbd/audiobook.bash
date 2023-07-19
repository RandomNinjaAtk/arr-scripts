#!/usr/bin/with-contenv bash
ScriptVersion="0.1"
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
		if [ $(find "$1" -type f -regex ".*/.*\.\(m4b\)" | wc -l) -gt 0 ]; then
			find "$1" -type f -not -regex ".*/.*\.\(m4b\)" -delete
			find "$1" -mindepth 2 -type f -exec mv "{}" "$1"/ \;
			find "$1" -mindepth 1 -type d -delete
		else
			echo "ERROR: NO AUDIOBOOK FILES FOUND (M4B)" && exit 1
		fi
}

clean
exit

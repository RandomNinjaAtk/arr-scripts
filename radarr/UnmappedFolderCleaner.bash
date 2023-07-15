#!/usr/bin/env bash
scriptVersion="1.0.2"

if [ -z "$arrUrl" ] || [ -z "$arrApiKey" ]; then
  arrUrlBase="$(cat /config/config.xml | xq | jq -r .Config.UrlBase)"
  if [ "$arrUrlBase" == "null" ]; then
    arrUrlBase=""
  else
    arrUrlBase="/$(echo "$arrUrlBase" | sed "s/\///g")"
  fi
  arrApiKey="$(cat /config/config.xml | xq | jq -r .Config.ApiKey)"
  arrPort="$(cat /config/config.xml | xq | jq -r .Config.Port)"
  arrUrl="http://127.0.0.1:${arrPort}${arrUrlBase}"
fi

# auto-clean up log file to reduce space usage
if [ -f "/config/logs/UnmappedFolderCleaner.txt" ]; then
	find /config/logs -type f -name "UnmappedFolderCleaner.txt" -size +1024k -delete
fi

if [ ! -f "/config/logs/UnmappedFolderCleaner.txt" ]; then
    touch "/config/logs/UnmappedFolderCleaner.txt"
    chmod 777 "/config/logs/UnmappedFolderCleaner.txt"
fi
exec &> >(tee -a "/config/logs/UnmappedFolderCleaner.txt")

log () {
  m_time=`date "+%F %T"`
  echo $m_time" :: UnmappedFolderCleaner :: $scriptVersion :: "$1
}

log "Finding UnmappedFolders to purge..."
OLDIFS="$IFS"
IFS=$'\n'
unmappedFolders=$(curl -s "$arrUrl/api/v3/rootFolder" -H "X-Api-Key: $arrApiKey" | jq -r ".[].unmappedFolders[].path")
unmappedFoldersCount=$(echo -n "$unmappedFolders" | wc -l)
log "$unmappedFoldersCount Folders Found!"
if [ $unmappedFoldersCount = 0 ]; then 
    log "No cleanup required, exiting..."
    exit
fi
for folder in $(echo "$unmappedFolders"); do
    log "Removing $folder"
    rm -rf "$folder"
done
IFS="$OLDIFS"

exit

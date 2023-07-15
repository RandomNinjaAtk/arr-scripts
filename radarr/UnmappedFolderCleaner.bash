#!/usr/bin/env bash
scriptVersion="1.0"
scriptName="UnmappedFolderCleaner"

log () {
  m_time=`date "+%F %T"`
  echo $m_time" :: $scriptName :: $scriptVersion :: "$1
}

logfileSetup () {
  # auto-clean up log file to reduce space usage
  if [ -f "/config/logs/UnmappedFolderCleaner.txt" ]; then
  	find /config/logs -type f -name "UnmappedFolderCleaner.txt" -size +1024k -delete
  fi
  
  if [ ! -f "/config/logs/UnmappedFolderCleaner.txt" ]; then
      touch "/config/logs/UnmappedFolderCleaner.txt"
      chmod 666 "/config/logs/UnmappedFolderCleaner.txt"
  fi
  exec &> >(tee -a "/config/logs/UnmappedFolderCleaner.txt")
}

verifyConfig () {
  #### Import Settings
  source /config/extended.conf

  if [ "$enableUnmappedFolderCleaner" != "true" ]; then
    log "Script is not enabled, enable by setting enableUnmappedFolderCleaner to \"true\" by modifying the \"/config/extended.conf\" config file..."
    log "Sleeping (infinity)"
    sleep infinity
  fi

  if [ -z "$unmappedFolderCleanerScriptInterval" ]; then
    unmappedFolderCleanerScriptInterval="1h"
  fi
}

getArrAppInfo () {
  # Get Arr App information
  if [ -z "$arrUrl" ] || [ -z "$arrApiKey" ]; then
    arrUrlBase="$(cat /config/config.xml | xq | jq -r .Config.UrlBase)"
    if [ "$arrUrlBase" == "null" ]; then
      arrUrlBase=""
    else
      arrUrlBase="/$(echo "$arrUrlBase" | sed "s/\///g")"
    fi
    arrName="$(cat /config/config.xml | xq | jq -r .Config.InstanceName)"
    arrApiKey="$(cat /config/config.xml | xq | jq -r .Config.ApiKey)"
    arrPort="$(cat /config/config.xml | xq | jq -r .Config.Port)"
    arrUrl="http://127.0.0.1:${arrPort}${arrUrlBase}"
  fi
  if [ "$arrPort" == "7878" ]; then
    recylcarrApp="radarr"
  fi
  if [ "$arrPort" == "8989" ]; then
    recylcarrApp="sonarr"
  fi
}

verifyApiAccess () {
  until false
  do
    arrApiTest=""
    arrApiVersion=""
    if [ "$arrPort" == "8989" ] || [ "$arrPort" == "7878" ]; then
      arrApiVersion="v3"
    elif [ "$arrPort" == "8686" ] || [ "$arrPort" == "8787" ]; then
      arrApiVersion="v1"
    fi
    arrApiTest=$(curl -s "$arrUrl/api/$arrApiVersion/system/status?apikey=$arrApiKey" | jq -r .instanceName)
    if [ "$arrApiTest" == "$arrName" ]; then
      break
    else
      log "$arrName is not ready, sleeping until valid response..."
      sleep 1
    fi
  done
}

UnmappedFolderCleanerProcess () {
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
 }


# Loop Script
for (( ; ; )); do
	let i++
	logfileSetup
    	verifyConfig
	getArrAppInfo
	verifyApiAccess
	UnmappedFolderCleanerProcess
	log "Script sleeping for $recyclarrScriptInterval..."
	sleep $recyclarrScriptInterval
done

exit

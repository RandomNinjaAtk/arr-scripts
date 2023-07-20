#!/usr/bin/env bash
scriptVersion="1.4"
scriptName="UnmappedFolderCleaner"

#### Import Settings
source /config/extended.conf
#### Import Functions
source /config/extended/functions
#### Create Log File
logfileSetup

verifyConfig () {

  if [ "$enableUnmappedFolderCleaner" != "true" ]; then
    log "Script is not enabled, enable by setting enableUnmappedFolderCleaner to \"true\" by modifying the \"/config/extended.conf\" config file..."
    log "Sleeping (infinity)"
    sleep infinity
  fi

  if [ -z "$unmappedFolderCleanerScriptInterval" ]; then
    unmappedFolderCleanerScriptInterval="1h"
  fi
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
	    return
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
 	log "Script starting..."
    	verifyConfig
	getArrAppInfo
	verifyApiAccess
	UnmappedFolderCleanerProcess
	log "Script sleeping for $unmappedFolderCleanerScriptInterval..."
	sleep $unmappedFolderCleanerScriptInterval
done

exit

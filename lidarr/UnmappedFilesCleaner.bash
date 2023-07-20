#!/usr/bin/with-contenv bash
scriptVersion="1.3"
scriptName="UnmappedFilesCleaner"

#### Import Settings
source /config/extended.conf
#### Import Functions
source /config/extended/functions

verifyConfig () {
  if [ "$enableUnmappedFilesCleaner" != "true" ]; then
    log "Script is not enabled, enable by setting enableUnmappedFilesCleaner to \"true\" by modifying the \"/config/extended.conf\" config file..."
    log "Sleeping (infinity)"
    sleep infinity
  fi

  if [ -z "$unmappedFolderCleanerScriptInterval" ]; then
    unmappedFolderCleanerScriptInterval="15m"
  fi
}

UnmappedFilesCleanerProcess () {
    log "Finding UnmappedFiles to purge..."
    OLDIFS="$IFS"
    IFS=$'\n'    
    unamppedFilesData="$(curl -s "$arrUrl/api/v1/trackFile?unmapped=true" -H 'Content-Type: application/json' -H "X-Api-Key: $arrApiKey" | jq -r .[])"
    unamppedFileIds="$(curl -s "$arrUrl/api/v1/trackFile?unmapped=true" -H 'Content-Type: application/json' -H "X-Api-Key: $arrApiKey" | jq -r .[].id)"

    if [ -z "$unamppedFileIds" ]; then
      log "No unmapped files to process"
      return
    fi

    for id  in $(echo "$unamppedFileIds"); do 
      unmappedFilePath=$(echo "$unamppedFilesData" | jq -r ". | select(.id==$id)| .path")
      unmappedFileName=$(basename "$unmappedFilePath")
      unmappedFileDirectory=$(dirname "$unmappedFilePath")
      if [ -d "$unmappedFileDirectory" ]; then
          log "Deleting \"$unmappedFileDirectory\""
          rm -rf "$unmappedFileDirectory"
      fi
      log "Removing $unmappedFileName ($id) entry from lidarr..."
      lidarrCommand=$(curl -s "$arrUrl/api/v1/trackFile/$id" -X DELETE  -H "X-Api-Key: $arrApiKey")
    done
}

# Loop Script
for (( ; ; )); do
	let i++
	logfileSetup
 	log "Script starting..."
  verifyConfig
	getArrAppInfo
	verifyApiAccess
	UnmappedFilesCleanerProcess
	log "Script sleeping for $unmappedFolderCleanerScriptInterval..."
	sleep $unmappedFolderCleanerScriptInterval
done

exit

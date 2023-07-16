#!/usr/bin/env bash
scriptVersion="1.0"
scriptName="AutoConfig"

log () {
  m_time=`date "+%F %T"`
  echo $m_time" :: $scriptName :: $scriptVersion :: "$1
}

logfileSetup () {
  # auto-clean up log file to reduce space usage
  if [ -f "/config/logs/$scriptName.txt" ]; then
    find /config/logs -type f -name "$scriptName.txt" -size +5000k -delete
    sleep 0.01
  fi
  touch "/config/logs/$scriptName.txt"
  exec &> >(tee -a "/config/logs/$scriptName.txt")
  chmod 666 "/config/logs/$scriptName.txt"
}

verifyConfig () {
  #### Import Settings
  source /config/extended.conf

  if [ "$enableAutoConfig" != "true" ]; then
    log "Script is not enabled, enable by setting enableAutoConfig to \"true\" by modifying the \"/config/extended.conf\" config file..."
    log "Sleeping (infinity)"
    sleep infinity
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

logfileSetup
log "Script starting..."
verifyConfig
getArrAppInfo
verifyApiAccess



autoConfigJson=$(cat /config/extended/AutoConfig.json)
renameBooks=$(echo "$autoConfigJson" | jq -r '.MediaManagement[].renameBooks')
replaceIllegalCharacters=$(echo "$autoConfigJson" | jq -r '.MediaManagement[].replaceIllegalCharacters')
standardBookFormat=$(echo "$autoConfigJson" | jq -r '.MediaManagement[].standardBookFormat')
authorFolderFormat=$(echo "$autoConfigJson" | jq -r '.MediaManagement[].authorFolderFormat')
deleteEmptyFolders=$(echo "$autoConfigJson" | jq -r '.MediaManagement[].deleteEmptyFolders')
watchLibraryForChanges=$(echo "$autoConfigJson" | jq -r '.MediaManagement[].watchLibraryForChanges')
chmodFolder=$(echo "$autoConfigJson" | jq -r '.MediaManagement[].chmodFolder')
fileDate=$(echo "$autoConfigJson" | jq -r '.MediaManagement[].fileDate')
writeAudioTags=$(echo "$autoConfigJson" | jq -r '.Metadata[].writeAudioTags')
scrubAudioTags=$(echo "$autoConfigJson" | jq -r '.Metadata[].scrubAudioTags')
writeBookTags=$(echo "$autoConfigJson" | jq -r '.Metadata[].writeBookTags')
updateCovers=$(echo "$autoConfigJson" | jq -r '.Metadata[].updateCovers')
embedMetadata=$(echo "$autoConfigJson" | jq -r '.Metadata[].embedMetadata')


log "Updating $arrAppName File Naming..."
updateArr=$(curl -s "$arrUrl/api/v1/config/naming" -X PUT -H "Content-Type: application/json" -H "X-Api-Key: $arrApiKey" --data-raw "{
	\"renameBooks\": $renameBooks,
	\"replaceIllegalCharacters\": $replaceIllegalCharacters,
	\"standardBookFormat\": \"$standardBookFormat\",
	\"authorFolderFormat\": \"$authorFolderFormat\",
	\"includeAuthorName\": false,
	\"includeBookTitle\": false,
	\"includeQuality\": false,
	\"replaceSpaces\": false,
	\"id\": 1
	}")    
log "Complete"

log "Updating $arrAppName  Media Management..."
updateArr=$(curl -s "$arrUrl/api/v3/config/mediamanagement" -X PUT -H "Content-Type: application/json" -H "X-Api-Key: $arrApiKey" --data-raw "{
  \"autoUnmonitorPreviouslyDownloadedBooks\": false,
  \"recycleBin\": \"\",
  \"recycleBinCleanupDays\": 7,
  \"downloadPropersAndRepacks\": \"preferAndUpgrade\",
  \"createEmptyAuthorFolders\": false,
  \"deleteEmptyFolders\": $deleteEmptyFolders,
  \"fileDate\": \"$fileDate\",
  \"watchLibraryForChanges\": $watchLibraryForChanges,
  \"rescanAfterRefresh\": \"always\",
  \"allowFingerprinting\": \"newFiles\",
  \"setPermissionsLinux\": false,
  \"chmodFolder\": \"$chmodFolder\",
  \"chownGroup\": \"\",
  \"skipFreeSpaceCheckWhenImporting\": false,
  \"minimumFreeSpaceWhenImporting\": 100,
  \"copyUsingHardlinks\": true,
  \"importExtraFiles\": false,
  \"extraFileExtensions\": \"srt\",
  \"id\": 1
  }")
log "Complete"

log "Updating $arrAppName Medata Settings..."
updateArr=$(curl -s "$arrUrl/api/v1/config/metadataProvider" -X PUT -H "Content-Type: application/json" -H "X-Api-Key: $arrApiKey" --data-raw "{
	\"writeAudioTags\":\"$writeAudioTags\",
	\"scrubAudioTags\":$scrubAudioTags,
	\"writeBookTags\":\"$writeBookTags\",
	\"updateCovers\":$updateCovers,
	\"embedMetadata\":$embedMetadata,
	\"id\":1
	}")
log "Complete"

log "Configuring $arrAppName Custom Scripts"
if curl -s "$arrUrl/api/v1/notification" -H "X-Api-Key: ${arrApiKey}" | jq -r .[].name | grep "PlexNotify.bash" | read; then
	log "PlexNotify.bash already added to $arrAppName custom scripts"
else
	log "Adding PlexNotify.bash to $arrAppName custom scripts"
  # Send a command to check file path, to prevent error with adding...
	updateArr=$(curl -s "$arrUrl/api/v3/filesystem?path=%2Fconfig%2Fextended%2Fscripts%2FPlexNotify.bash&allowFoldersWithoutTrailingSlashes=true&includeFiles=true" -H "X-Api-Key: ${arrApiKey}")
  
  # Add PlexNotify.bash
  updateArr=$(curl -s "$arrUrl/api/v1/notification?" -X POST -H "Content-Type: application/json" -H "X-Api-Key: ${arrApiKey}" --data-raw '{"onGrab":false,"onReleaseImport":true,"onUpgrade":true,"onRename":false,"onAuthorDelete":true,"onBookDelete":true,"onBookFileDelete":false,"onBookFileDeleteForUpgrade":false,"onHealthIssue":false,"onDownloadFailure":false,"onImportFailure":false,"onBookRetag":false,"onApplicationUpdate":false,"supportsOnGrab":true,"supportsOnReleaseImport":true,"supportsOnUpgrade":true,"supportsOnRename":true,"supportsOnAuthorDelete":true,"supportsOnBookDelete":true,"supportsOnBookFileDelete":true,"supportsOnBookFileDeleteForUpgrade":true,"supportsOnHealthIssue":true,"includeHealthWarnings":false,"supportsOnDownloadFailure":false,"supportsOnImportFailure":false,"supportsOnBookRetag":true,"supportsOnApplicationUpdate":true,"name":"PlexNotify.bash","fields":[{"name":"path","value":"/config/extended/scripts/PlexNotify.bash"},{"name":"arguments"}],"implementationName":"Custom Script","implementation":"CustomScript","configContract":"CustomScriptSettings","infoLink":"https://wiki.servarr.com/readarr/supported#customscript","message":{"message":"Testing will execute the script with the EventType set to Test, ensure your script handles this correctly","type":"warning"},"tags":[]}')
  log "Complete"
fi

log "Script sleeping for (infinity)..."
sleep infinity
exit

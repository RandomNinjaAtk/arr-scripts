#!/usr/bin/env bash
scriptVersion="1.0"
notifiedBy="Sonarr"
arrRootFolderPath="$(dirname "$sonarr_series_path")"
arrFolderPath="$sonarr_series_path"
arrEventType="$sonarr_eventtype"
extrasPath="$1"
scriptName="EmbyNotify"

#### Import Settings
source /config/extended.conf  # Assuming you have embyUrl and embyApiKey in this config file

log () {
  m_time=`date "+%F %T"`
  echo "$m_time :: $scriptName :: $scriptVersion :: $1"
}

# Auto-clean up log file to reduce space usage
if [ -f "/config/logs/EmbyNotify.txt" ]; then
	find /config/logs -type f -name "EmbyNotify.txt" -size +1024k -delete
fi

if [ ! -f "/config/logs/EmbyNotify.txt" ]; then
    touch "/config/logs/EmbyNotify.txt"
    chmod 666 "/config/logs/EmbyNotify.txt"
fi
exec &> >(tee -a "/config/logs/EmbyNotify.txt")

# If extras are enabled, update paths
if [ "$enableExtras" == "true" ]; then
    if [ -z "$extrasPath" ]; then
		log "Extras script is enabled, skipping..."
		exit
	fi
fi

if [ ! -z "$extrasPath" ]; then
	arrFolderPath="$extrasPath"
	if [ "$2" == "true" ]; then
		arrRootFolderPath="$extrasPath"
	else
		arrRootFolderPath="$(dirname "$extrasPath")"
	fi
fi

if [ "$arrEventType" == "Test" ]; then
	log "$notifiedBy :: Tested Successfully"
	exit 0	
fi

embyConnectionError () {
	log "ERROR :: Cannot communicate with Emby"
	log "ERROR :: Please check your embyUrl and embyApiKey"
	log "ERROR :: Configured embyUrl \"$embyUrl\""
	log "ERROR :: Configured embyApiKey \"$embyApiKey\""
	log "ERROR :: Exiting..."
	exit
}

# Validate connection
if curl -s "$embyUrl/emby/System/Info?api_key=$embyApiKey" | jq . &>/dev/null; then
	embyVersion=$(curl -s "$embyUrl/emby/System/Info?api_key=$embyApiKey" | jq -r '.Version')
	if [ -z "$embyVersion" ]; then
		# Error out if version is null, indicates bad token
		embyConnectionError
	else
		log "Emby Connection Established, version: $embyVersion"
	fi
else
	# Error out if error in curl | jq . command output
	embyConnectionError
fi

# Get Emby libraries
embyLibraries=$(curl -s "$embyUrl/emby/Library/VirtualFolders?api_key=$embyApiKey")
if [[ -z "$embyLibraries" ]]; then
	log "$notifiedBy :: ERROR: Failed to retrieve libraries from Emby"
	exit 1
fi

# Find matching Emby library for the given path
embyLibraryId=$(echo "$embyLibraries" | jq -r ".[] | select(.Locations[] | contains(\"$arrRootFolderPath\")) | .CollectionType")

if [[ -z "$embyLibraryId" ]]; then
	log "$notifiedBy :: ERROR: No Emby Library found containing path \"$arrRootFolderPath\""
	log "$notifiedBy :: ERROR: Add \"$arrRootFolderPath\" as a folder to an Emby Library"
	exit 1
else
	# Refresh only the relevant folder using its path
	log "$notifiedBy :: Emby Library found for path \"$arrRootFolderPath\", refreshing..."
	curl -X POST "$embyUrl/emby/Items/$embyLibraryId/Refresh?api_key=$embyApiKey"
	log "$notifiedBy :: Emby Scan notification sent for folder: $arrFolderPath"
fi

exit

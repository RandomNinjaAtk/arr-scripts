#!/usr/bin/env bash
scriptVersion="1.0"
scriptName="EmbyNotify"

#### Import Settings
source /config/extended.conf  # This will import embyUrl and embyApiKey

log () {
  m_time=$(date "+%F %T")
  echo "$m_time :: $scriptName :: $scriptVersion :: $1"
}

notifiedBy="Radarr"
arrRootFolderPath="$(dirname "$radarr_movie_path")"
arrFolderPath="$radarr_movie_path"
arrEventType="$radarr_eventtype"
movieExtrasPath="$1"

# auto-clean up log file to reduce space usage
if [ -f "/config/logs/EmbyNotify.txt" ]; then
	find /config/logs -type f -name "EmbyNotify.txt" -size +1024k -delete
fi

if [ ! -f "/config/logs/EmbyNotify.txt" ]; then
    touch "/config/logs/EmbyNotify.txt"
    chmod 777 "/config/logs/EmbyNotify.txt"
fi
exec &> >(tee -a "/config/logs/EmbyNotify.txt")

if [ "$arrEventType" == "Test" ]; then
	log "$notifiedBy :: Tested Successfully"
	exit 0	
fi

EmbyConnectionError () {
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
		EmbyConnectionError
	else
		log "Emby Connection Established, version: $embyVersion"
	fi
else
	# Error out if error in curl | jq . command output
	EmbyConnectionError
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

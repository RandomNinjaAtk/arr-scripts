#!/usr/bin/env bash
scriptVersion="1.3"
notfidedBy="Sonarr"
arrRootFolderPath="$(dirname "$sonarr_series_path")"
arrFolderPath="$sonarr_series_path"
arrEventType="$sonarr_eventtype"
extrasPath="$1"
scriptName="PlexNotify"

#### Import Settings
source /config/extended.conf

log () {
  m_time=`date "+%F %T"`
  echo $m_time" :: $scriptName :: $scriptVersion :: "$1
}

# auto-clean up log file to reduce space usage
if [ -f "/config/logs/PlexNotify.txt" ]; then
	find /config/logs -type f -name "PlexNotify.txt" -size +1024k -delete
fi

if [ ! -f "/config/logs/PlexNotify.txt" ]; then
    touch "/config/logs/PlexNotify.txt"
    chmod 666 "/config/logs/PlexNotify.txt"
fi
exec &> >(tee -a "/config/logs/PlexNotify.txt")

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
	log "$notfidedBy :: Tested Successfully"
	exit 0	
fi

plexConnectionError () {
	log "ERROR :: Cannot communicate with Plex"
	log "ERROR :: Please check your plexUrl and plexToken"
	log "ERROR :: Configured plexUrl \"$plexUrl\""
	log "ERROR :: Configured plexToken \"$plexToken\""
	log "ERROR :: Exiting..."
	exit
}

# Validate connection
if curl -s "$plexUrl/?X-Plex-Token=$plexToken" | xq . &>/dev/null; then
	plexVersion=$(curl -s "$plexUrl/?X-Plex-Token=$plexToken" | xq . | jq -r '.MediaContainer."@version"')
	if [ "$plexVersion" == "null" ]; then
		# Error out if version is null, indicates bad token
		plexConnectionError
	else
		log "Plex Connection Established, version: $plexVersion"
	fi
else
	# Error out if error in curl | xq . command output
	plexConnectionError
fi

plexLibraries="$(curl -s "$plexUrl/library/sections?X-Plex-Token=$plexToken")"
plexLibraryData=$(echo "$plexLibraries" | xq ".MediaContainer.Directory")
if echo "$plexLibraryData" | grep "^\[" | read; then
	plexLibraryData=$(echo "$plexLibraries" | xq ".MediaContainer.Directory[]")
	plexKeys=($(echo "$plexLibraries" | xq ".MediaContainer.Directory[]" | jq -r '."@key"'))
else
	plexKeys=($(echo "$plexLibraries" | xq ".MediaContainer.Directory" | jq -r '."@key"'))
fi

if echo "$plexLibraryData" | grep "path" | grep "$arrRootFolderPath" | read; then
	sleep 0.01
else
	log "$notfidedBy :: ERROR: No Plex Library found containing path \"$arrRootFolderPath\""
	log "$notfidedBy :: ERROR: Add \"$arrRootFolderPath\" as a folder to a Plex TV Library"
	exit 1
fi

for key in ${!plexKeys[@]}; do
	plexKey="${plexKeys[$key]}"
	plexKeyData="$(echo "$plexLibraryData" | jq -r "select(.\"@key\"==\"$plexKey\")")"
	if echo "$plexKeyData" | grep "path" | grep "$arrRootFolderPath" | read; then
		plexFolderEncoded="$(jq -R -r @uri <<<"$arrFolderPath")"
		curl -s "$plexUrl/library/sections/$plexKey/refresh?path=$plexFolderEncoded&X-Plex-Token=$plexToken"
		log  "$notfidedBy :: Plex Scan notification sent! ($arrFolderPath)"
	fi
done

# Jellyfin Integration

jellyfinConnectionError () {
	log "ERROR :: Cannot communicate with Jellyfin"
	log "ERROR :: Please check your jellyfinUrl and jellyfinToken"
	log "ERROR :: Configured jellyfinUrl \"$jellyfinUrl\""
	log "ERROR :: Configured jellyfinToken \"$jellyfinToken\""
	log "ERROR :: Exiting..."
	exit
}

# Validate Jellyfin connection
log "Attempting to connect to Jellyfin..."
if curl -s "$jellyfinUrl/Library/MediaFolders?api_key=$jellyfinToken" &>/dev/null; then
	log "Jellyfin Connection Established"
else
	jellyfinConnectionError
fi

# Get Jellyfin Media Folders
log "Fetching Jellyfin media folders..."
jellyfinLibraries=$(curl -s "$jellyfinUrl/Library/MediaFolders?api_key=$jellyfinToken")
if [ -z "$jellyfinLibraries" ]; then
    log "ERROR :: Failed to fetch Jellyfin media folders. Check the API or Jellyfin server."
    exit 1
fi
jellyfinFolders=$(echo "$jellyfinLibraries" | jq -r '.Items[].Path')

# Log Jellyfin folders for debugging
log "Jellyfin media folders fetched: $jellyfinFolders"

# Jellyfin Library Path Matching
pathMatched="false"
for jellyfinPath in $jellyfinFolders; do
	if [[ "$arrRootFolderPath" == "$jellyfinPath"* ]]; then
		log "$notifiedBy :: Jellyfin path matched: $jellyfinPath"
		pathMatched="true"
		break
	fi
done

# Trigger Jellyfin Library Scan if match found
if [ "$pathMatched" == "true" ]; then
	log "Triggering Jellyfin library scan..."
	curl -s -X POST "$jellyfinUrl/Library/Refresh?api_key=$jellyfinToken"
	log "$notifiedBy :: Jellyfin Scan notification sent!"
else
	log "$notifiedBy :: ERROR: No Jellyfin Library found containing path \"$arrRootFolderPath\""
	log "$notifiedBy :: ERROR: Add \"$arrRootFolderPath\" as a folder to a Jellyfin Library"
fi

exit

#!/usr/bin/env bash
scriptVersion=1.0.7
if [ -z "$lidarr_artist_path" ]; then
	lidarr_artist_path="$1"
	notfidedBy=Extended_Script
else
	notfidedBy=Lidarr
fi
lidarrRootFolderPath="$(dirname "$lidarr_artist_path")"

# auto-clean up log file to reduce space usage
if [ -f "/config/logs/PlexNotify.txt" ]; then
	find /config/logs -type f -name "PlexNotify.txt" -size +1024k -delete
fi

exec &> >(tee -a "/config/logs/PlexNotify.txt")
chmod 666 "/config/logs/PlexNotify.txt"

log () {
    m_time=`date "+%F %T"`
    echo $m_time" :: PlexNotify :: $scriptVersion :: "$1
}

if [ "$lidarr_eventtype" == "Test" ]; then
	log "Tested Successfully"
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
if echo "$plexLibraries" | xq ".MediaContainer.Directory | select(.\"@type\"==\"artist\")" &>/dev/null; then
	plexKeys=($(echo "$plexLibraries" | xq ".MediaContainer.Directory | select(.\"@type\"==\"artist\")" | jq -r '."@key"'))
	plexLibraryData=$(echo "$plexLibraries" | xq ".MediaContainer.Directory | select(.\"@type\"==\"artist\")")
elif echo "$plexLibraries" | xq ".MediaContainer.Directory[] | select(.\"@type\"==\"artist\")" &>/dev/null; then 
	plexKeys=($(echo "$plexLibraries" | xq ".MediaContainer.Directory[] | select(.\"@type\"==\"artist\")" | jq -r '."@key"'))
	plexLibraryData=$(echo "$plexLibraries" | xq ".MediaContainer.Directory[] | select(.\"@type\"==\"artist\")")
else
	log "ERROR: No Plex Music Type libraries found"
	log "ERROR: Exiting..."
	exit 1
fi

if echo "$plexLibraryData" | grep "\"@path\": \"$lidarrRootFolderPath" | read; then
	sleep 0.01
else
	log "ERROR: No Plex Library found containing path \"$lidarrRootFolderPath\""
	log "ERROR: Add \"$lidarrRootFolderPath\" as a folder to a Plex Music Library"
	exit 1
fi

for key in ${!plexKeys[@]}; do
	plexKey="${plexKeys[$key]}"
	plexKeyLibraryData=$(echo "$plexLibraryData" | jq -r "select(.\"@key\"==\"$plexKey\")")
	if echo "$plexKeyLibraryData" | grep "\"@path\": \"$lidarrRootFolderPath" | read; then
		plexFolderEncoded="$(jq -R -r @uri <<<"$lidarr_artist_path")"
		curl -s "$plexUrl/library/sections/$plexKey/refresh?path=$plexFolderEncoded&X-Plex-Token=$plexToken"
		log  "Plex Scan notification sent! ($plexKey :: $lidarr_artist_path)"
	fi
done

exit

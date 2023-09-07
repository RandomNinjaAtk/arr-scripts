#!/usr/bin/env bash
scriptVersion="1.0"
scriptName="LyricExtractor"

#### Import Settings
source /config/extended.conf
#### Import Functions
source /config/extended/functions
#### Create Log File
logfileSetup

if [ -z "$lidarr_album_id" ]; then
	lidarr_album_id="$1"
fi

SECONDS=0

if [ "$lidarr_eventtype" == "Test" ]; then
	log "Tested Successfully"
	exit 0	
fi

getAlbumArtist="$(curl -s "$lidarrUrl/api/v1/album/$lidarr_album_id" -H "X-Api-Key: ${lidarrApiKey}" | jq -r .artist.artistName)"
getAlbumArtistPath="$(curl -s "$lidarrUrl/api/v1/album/$lidarr_album_id" -H "X-Api-Key: ${lidarrApiKey}" | jq -r .artist.path)"
getTrackPath="$(curl -s "$lidarrUrl/api/v1/trackFile?albumId=$lidarr_album_id" -H "X-Api-Key: ${lidarrApiKey}" | jq -r .[].path | head -n1)"
getFolderPath="$(dirname "$getTrackPath")"

if echo "$getFolderPath" | grep "$getAlbumArtistPath" | read; then
	if [ ! -d "$getFolderPath" ]; then
		log "ERROR :: \"$getFolderPath\" Folder is missing :: Exiting..."
	fi
else 
	log "ERROR :: $getAlbumArtistPath not found within \"$getFolderPath\" :: Exiting..."
	exit
fi

if ls "$getFolderPath" | grep "lrc" | read; then
    log "Processing :: $getAlbumFolderName :: Removing existing lrc files"
    find "$getFolderPath" -type f -iname "*.lrc" -delete
fi

find "$getFolderPath" -type f -regex ".*/.*\.\(flac\|opus\|m4a\|mp3\)" -print0 | while IFS= read -r -d '' file; do
    fileName=$(basename -- "$file")
    fileExt="${fileName##*.}"
    fileNameNoExt="${fileName%.*}"

    if [ "$fileExt" == "flac" ]; then
        log "Processing :: $getAlbumFolderName :: $fileName :: Getting Lyrics from embedded metadata"
        getLyrics="$(ffprobe -loglevel 0 -print_format json -show_format -show_streams "$file" | jq -r ".format.tags.LYRICS" 2>/dev/null | sed "s/null//g" | sed "/^$/d")"
    fi

    if [ "$fileExt" == "opus" ]; then
        log "Processing :: $getAlbumFolderName :: $fileName :: Getting Lyrics from embedded metadata"
        getLyrics="$(ffprobe -loglevel 0 -print_format json -show_format -show_streams "$file" | jq -r ".streams[].tags.LYRICS" 2>/dev/null | sed "s/null//g" | sed "/^$/d")"
    fi    
done

duration=$SECONDS
log "Processing :: $getAlbumFolderName :: Finished in $(($duration / 60 )) minutes and $(($duration % 60 )) seconds!"
exit

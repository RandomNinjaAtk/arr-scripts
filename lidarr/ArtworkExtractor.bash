#!/usr/bin/env bash
scriptVersion="1.2"
scriptName="ArtworkExtractor"

#### Import Settings
source /config/extended.conf
#### Import Functions
source /config/extended/functions
#### Create Log File
logfileSetup

SECONDS=0

if [ "$lidarr_eventtype" == "Test" ]; then
	log "Tested Successfully"
	exit 0	
fi

getArrAppInfo
verifyApiAccess

if [ -z "$lidarr_album_id" ]; then
	lidarr_album_id="$1"
fi



getAlbumArtist="$(curl -s "$arrUrl/api/v1/album/$lidarr_album_id" -H "X-Api-Key: ${arrApiKey}" | jq -r .artist.artistName)"
getAlbumArtistPath="$(curl -s "$arrUrl/api/v1/album/$lidarr_album_id" -H "X-Api-Key: ${arrApiKey}" | jq -r .artist.path)"
getTrackPath="$(curl -s "$arrUrl/api/v1/trackFile?albumId=$lidarr_album_id" -H "X-Api-Key: ${arrApiKey}" | jq -r .[].path | head -n1)"
getFolderPath="$(dirname "$getTrackPath")"
getAlbumFolderName="$(basename "$getFolderPath")"

log "Processing :: $getAlbumFolderName :: Processing Files..."

if echo "$getFolderPath" | grep "$getAlbumArtistPath" | read; then
	if [ ! -d "$getFolderPath" ]; then
		log "ERROR :: \"$getFolderPath\" Folder is missing :: Exiting..."
	fi
else 
	log "ERROR :: $getAlbumArtistPath not found within \"$getFolderPath\" :: Exiting..."
	exit
fi

find "$getFolderPath" -type f -regex ".*/.*\.\(flac\|opus\|m4a\|mp3\)" -print0 | while IFS= read -r -d '' file; do
    fileName=$(basename -- "$file")
    fileExt="${fileName##*.}"
    fileNameNoExt="${fileName%.*}"

    if [ ! -f "$getFolderPath/folder.jpg" ] && [ ! -f "$getFolderPath/folder.jpeg" ]; then
        log "Processing :: $getAlbumFolderName :: $fileName :: Extracting Artwork..."
        ffmpeg -i "$file" -an -vcodec copy "$getFolderPath/folder.jpg" &> /dev/null
        if [ -f "$getFolderPath/folder.jpg" ] && [ -f "$getFolderPath/folder.jpeg" ]; then
            log "Processing :: $getAlbumFolderName :: Album Artwork Extracted to: $getFolderPath/folder.jpg"
            chmod 666 "$getFolderPath/folder.jpg"
        fi
    else
      log "Processing :: $getAlbumFolderName :: Album Artwork Exists, exiting..."
      exit
    fi
done

duration=$SECONDS
log "Processing :: $getAlbumFolderName :: Finished in $(($duration / 60 )) minutes and $(($duration % 60 )) seconds!"
exit

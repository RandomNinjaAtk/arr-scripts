#!/usr/bin/env bash
scriptVersion="1.5"
scriptName="LyricExtractor"

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
        if [ -z "$getLyrics" ]; then
            getLyrics="$(ffprobe -loglevel 0 -print_format json -show_format -show_streams "$file" | jq -r ".format.tags.Lyrics" 2>/dev/null | sed "s/null//g" | sed "/^$/d")"
        fi
        if [ -z "$getLyrics" ]; then
            getLyrics="$(ffprobe -loglevel 0 -print_format json -show_format -show_streams "$file" | jq -r ".format.tags.lyrics" 2>/dev/null | sed "s/null//g" | sed "/^$/d")"
        fi
    fi

    if [ "$fileExt" == "opus" ]; then
        log "Processing :: $getAlbumFolderName :: $fileName :: Getting Lyrics from embedded metadata"
        getLyrics="$(ffprobe -loglevel 0 -print_format json -show_format -show_streams "$file" | jq -r ".streams[].tags.LYRICS" 2>/dev/null | sed "s/null//g" | sed "/^$/d")"
        if [ -z "$getLyrics" ]; then
            getLyrics="$(ffprobe -loglevel 0 -print_format json -show_format -show_streams "$file" | jq -r ".streams[].tags.Lyrics" 2>/dev/null | sed "s/null//g" | sed "/^$/d")"
        fi
        if [ -z "$getLyrics" ]; then
            getLyrics="$(ffprobe -loglevel 0 -print_format json -show_format -show_streams "$file" | jq -r ".streams[].tags.lyrics" 2>/dev/null | sed "s/null//g" | sed "/^$/d")"
        fi
    fi

    if [ ! -z "$getLyrics" ]; then
        lrcFile="${file%.*}.lrc"
        log "Processing :: $getAlbumFolderName :: $fileName :: Extracting Lyrics..."
        echo -n "$getLyrics" > "$lrcFile"
        log "Processing :: $getAlbumFolderName :: $fileName :: Lyrics extracted to: $fileNameNoExt.lrc"
        chmod 666 "$lrcFile"
    else
        log "Processing :: $getAlbumFolderName :: $fileName :: Lyrics not found..."
    fi
done

duration=$SECONDS
log "Processing :: $getAlbumFolderName :: Finished in $(($duration / 60 )) minutes and $(($duration % 60 )) seconds!"
exit

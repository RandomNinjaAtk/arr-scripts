#!/usr/bin/env bash
# Experimental
scriptVersion="1.0"
scriptName="TidalVideo"

#### Import Settings
source /config/extended.conf
#### Import Functions
source /config/extended/functions

getArrAppInfo
verifyApiAccess
videoDownloadPath="$downloadPath/tidal/videos"

if [ -d $videoDownloadPath ]; then
	rm -rf "$videoDownloadPath"
fi

TidalClientSetup () {
	log "TIDAL :: Verifying tidal-dl configuration"
	
	tidal-dl -o "$videoDownloadPath"/incomplete 2>&1 | tee -a /config/logs/$scriptName.txt
	tidalQuality=HiFi

	if [ ! -f /config/xdg/.tidal-dl.token.json ]; then
		#log "TIDAL :: ERROR :: Downgrade tidal-dl for workaround..."
		#pip3 install tidal-dl==2022.3.4.2 --no-cache-dir &>/dev/null
		log "TIDAL :: ERROR :: Loading client for required authentication, please authenticate, then exit the client..."
		NotifyWebhook "FatalError" "TIDAL requires authentication, please authenticate now (check logs)"
		tidal-dl
	fi
	
	if [ ! -d "$videoDownloadPath/incomplete" ]; then
		mkdir -p "$videoDownloadPath"/incomplete
		chmod 777 "$videoDownloadPath"/incomplete
	else
		rm -rf "$videoDownloadPath"/incomplete/*
	fi
	
	#log "TIDAL :: Upgrade tidal-dl to newer version..."
	#pip3 install tidal-dl==2022.07.06.1 --no-cache-dir &>/dev/null
	
}

TidaldlStatusCheck () {
	until false
	do
        running=no
        if ps aux | grep "tidal-dl" | grep -v "grep" | read; then 
            running=yes
            log "STATUS :: TIDAL-DL :: BUSY :: Pausing/waiting for all active tidal-dl tasks to end..."
            sleep 2
            continue
        fi
		break
	done
}

TidalClientTest () { 
	log "TIDAL :: tidal-dl client setup verification..."
	i=0
	while [ $i -lt 3 ]; do
		i=$(( $i + 1 ))
  		TidaldlStatusCheck
		tidal-dl -q Normal -o "$videoDownloadPath"/incomplete -l "$tidalClientTestDownloadId" 2>&1 | tee -a /config/logs/$scriptName.txt
		downloadCount=$(find "$videoDownloadPath"/incomplete -type f -regex ".*/.*\.\(flac\|opus\|m4a\|mp3\)" | wc -l)
		if [ $downloadCount -le 0 ]; then
			continue
		else
			break
		fi
	done
 	tidalClientTest="unknown"
	if [ $downloadCount -le 0 ]; then
		if [ -f /config/xdg/.tidal-dl.token.json ]; then
			rm /config/xdg/.tidal-dl.token.json
		fi
		log "TIDAL :: ERROR :: Download failed"
		log "TIDAL :: ERROR :: You will need to re-authenticate on next script run..."
		log "TIDAL :: ERROR :: Exiting..."
		rm -rf "$videoDownloadPath"/incomplete/*
		NotifyWebhook "Error" "TIDAL not authenticated but configured"
  		tidalClientTest="failed"
		exit
	else
		rm -rf "$videoDownloadPath"/incomplete/*
		log "TIDAL :: Successfully Verified"
  		tidalClientTest="success"
	fi
}

TidalClientSetup


lidarrArtists=$(wget --timeout=0 -q -O - "$arrUrl/api/v1/artist?apikey=$arrApiKey" | jq -r .[])
lidarrArtistIds=$(echo $lidarrArtists | jq -r .id)
lidarrArtistCount=$(echo "$lidarrArtistIds" | wc -l)
for lidarrArtistId in $(echo $lidarrArtistIds); do
    processCount=$(( $processCount + 1))
    lidarrArtistData=$(wget --timeout=0 -q -O - "$arrUrl/api/v1/artist/$lidarrArtistId?apikey=$arrApiKey")
  	lidarrArtistName=$(echo $lidarrArtistData | jq -r .artistName)
  	lidarrArtistMusicbrainzId=$(echo $lidarrArtistData | jq -r .foreignArtistId)
	lidarrArtistPath="$(echo "${lidarrArtistData}" | jq -r " .path")"
    lidarrArtistFolder="$(basename "${lidarrArtistPath}")"
    lidarrArtistFolderNoDisambig="$(echo "$lidarrArtistFolder" | sed "s/ (.*)$//g" | sed "s/\.$//g")" # Plex Sanitization, remove disambiguation

	artistGenres=""
    OLDIFS="$IFS"
	IFS=$'\n'
	artistGenres=($(echo $lidarrArtistData | jq -r ".genres[]"))
	IFS="$OLDIFS"

    if [ ! -z "$artistGenres" ]; then
        for genre in ${!artistGenres[@]}; do
    	    artistGenre="${artistGenres[$genre]}"
            OUT=$OUT"$artistGenre / "
        done
        genre="${OUT%???}"
    else
        genre=""
    fi
    tidalArtistUrl=$(echo "${lidarrArtistData}" | jq -r ".links | .[] | select(.name==\"tidal\") | .url")
	tidalArtistIds="$(echo "$tidalArtistUrl" | grep -o '[[:digit:]]*' | sort -u | head -n1)"
    lidarrArtistTrackData=$(wget --timeout=0 -q -O - "$arrUrl/api/v1/track?artistId=$lidarrArtistId&apikey=${arrApiKey}" | jq -r .[].title)
    log "$processCount/$lidarrArtistCount :: $lidarrArtistName :: Getting Tidal Video Data..."
    tidalVideosData=$(curl -s "https://api.tidal.com/v1/artists/${tidalArtistIds}/videos?countryCode=${tidalCountryCode}&offset=0&limit=100" -H "x-tidal-token: CzET4vdadNUFQ5JU" | jq -r ".items | sort_by(.explicit) | reverse | .[]")
    tidalVideoIds=$(echo $tidalVideosData | jq -r .id)
    tidalVideoIdsCount=$(echo "$tidalVideosData" | wc -l)
    tidalVideoProcessNumber=0
    for id in $(echo "$tidalVideoIds"); do
        tidalVideoProcessNumber=$(( $tidalVideoProcessNumber + 1 ))
        videoData=$(echo $tidalVideosData | jq -r "select(.id==$id)")
        videoTitle=$(echo $videoData | jq -r .title)
        videoExplicit=$(echo $videoData | jq -r .explicit)
		videoUrl="https://tidal.com/browse/video/$id"
		videoDate="$(echo "$videoData" | jq -r ".releaseDate")"
		videoDate="${videoDate:0:10}"
        videoYear="${videoDate:0:4}"
        videoImageId="$(echo "$videoData" | jq -r ".imageId")"
        videoImageIdFix="$(echo "$videoImageId" | sed "s/-/\//g")"
        videoThumbnailUrl="https://resources.tidal.com/images/$videoImageIdFix/750x500.jpg"
		videoSource="tidal"


        log "$processCount/$lidarrArtistCount :: $lidarrArtistName :: $tidalVideoProcessNumber/$tidalVideoIdsCount :: $videoTitle"
        echo $videoExplicit
		echo $videoUrl
		echo $videoDate
		echo $videoYear
		echo $videoImageId
		echo $videoImageIdFix
		echo $videoThumbnailUrl
		echo $videoSource

        if echo "$videoTitle" | grep -i "official" | grep -i "video" | read; then
            log "$processCount/$lidarrArtistCount :: $lidarrArtistName :: $tidalVideoProcessNumber/$tidalVideoIdsCount :: $videoTitle :: Official Music Video Match Found!"
			videoType="-video"
        elif echo "$videoTitle" | grep -i "official" | grep -i "lyric" | read; then
            log "$processCount/$lidarrArtistCount :: $lidarrArtistName :: $tidalVideoProcessNumber/$tidalVideoIdsCount :: $videoTitle :: Official Lyric Video Match Found!"
			videoType="-lyrics"
        elif echo "$videoTitle" | grep -i "video" | grep -i "lyric" | read; then
            log "$processCount/$lidarrArtistCount :: $lidarrArtistName :: $tidalVideoProcessNumber/$tidalVideoIdsCount :: $videoTitle :: Official Lyric Video Match Found!"
			videoType="-lyrics"
        elif echo "$videoTitle" | grep -i "4k upgrade" | read; then
            log "$processCount/$lidarrArtistCount :: $lidarrArtistName :: $tidalVideoProcessNumber/$tidalVideoIdsCount :: $videoTitle :: 4K Upgrade Found!"
			videoType="-video" 
        elif echo "$videoTitle" | grep -i "\(.*live.*\)" | read; then
            log "$processCount/$lidarrArtistCount :: $lidarrArtistName :: $tidalVideoProcessNumber/$tidalVideoIdsCount :: $videoTitle :: Live Video Found!"
			videoType="-live"
        elif echo $lidarrArtistTrackData | grep -i "$videoTitle" | read; then
            log "$processCount/$lidarrArtistCount :: $lidarrArtistName :: $tidalVideoProcessNumber/$tidalVideoIdsCount :: $videoTitle :: Music Video Track Name Match Found!"
			videoType="-video" 
        else
            log "$processCount/$lidarrArtistCount :: $lidarrArtistName :: $tidalVideoProcessNumber/$tidalVideoIdsCount :: $videoTitle :: ERROR :: Unable to match!"
            continue
        fi

		videoFileName="${videoTitle}${videoType}.mkv"

		if [ -f "$videoPath/$lidarrArtistFolderNoDisambig/${videoFileName}" ]; then
			log "$processCount/$lidarrArtistCount :: $lidarrArtistName :: $tidalVideoProcessNumber/$tidalVideoIdsCount :: $videoTitle :: Already Downloaded, skipping..."
			continue
		fi



		if [ ! -d "$videoDownloadPath/incomplete" ]; then
			mkdir -p "$videoDownloadPath/incomplete"
		fi

		log "$processCount/$lidarrArtistCount :: $lidarrArtistName :: $tidalVideoProcessNumber/$tidalVideoIdsCount :: $videoTitle :: Downloading..."
        tidal-dl -q HiFi -o "$videoDownloadPath/incomplete" -l "$videoUrl"
        find "$videoDownloadPath/incomplete" -type f -exec mv "{}" "$videoDownloadPath/incomplete"/ \;
        find "$videoDownloadPath/incomplete" -mindepth 1 -type d -exec rm -rf "{}" \; &>/dev/null
        find "$videoDownloadPath/incomplete" -type f -regex ".*/.*\.\(mkv\|mp4\)"  -print0 | while IFS= read -r -d '' video; do
            file="${video}"
            filenoext="${file%.*}"
            filename="$(basename "$video")"
            extension="${filename##*.}"
            filenamenoext="${filename%.*}"
            mv "$file" "$videoDownloadPath/$filename"
        

			if [ -f "$videoDownloadPath/$filename" ]; then
				chmod 666 "$videoDownloadPath/$filename"
				downloadFailed=false
			else
				continue 2
			fi

			if [ "$videoDownloadPath/incomplete" ]; then
				rm -rf "$videoDownloadPath/incomplete"
			fi

			if python3 /usr/local/sma/manual.py --config "/config/extended/sma.ini" -i "$videoDownloadPath/$filename" -nt; then
            	sleep 0.01
				log "$processCount/$lidarrArtistCount :: $lidarrArtistName :: $tidalVideoProcessNumber/$tidalVideoIdsCount :: $videoTitle :: Processed with SMA..."
				rm  /usr/local/sma/config/*log*
			else
				log "$processCount/$lidarrArtistCount :: $lidarrArtistName :: $tidalVideoProcessNumber/$tidalVideoIdsCount :: $videoTitle :: ERROR: SMA Processing Error"
				rm "$videoDownloadPath/$filename"
				log "$processCount/$lidarrArtistCount :: $lidarrArtistName :: $tidalVideoProcessNumber/$tidalVideoIdsCount :: $videoTitle :: INFO: deleted: $filename"
			fi

			if [ -f "$videoDownloadPath/${filenamenoext}.mkv" ]; then
				curl -s "$videoThumbnailUrl" -o "$videoDownloadPath/poster.jpg"
				log "$processCount/$lidarrArtistCount :: $lidarrArtistName :: $tidalVideoProcessNumber/$tidalVideoIdsCount :: $videoTitle :: Tagging file"
				ffmpeg -y \
					-i "$videoDownloadPath/${filenamenoext}.mkv" \
					-c copy \
					-metadata TITLE="$videoTitle" \
					-metadata DATE_RELEASE="$videoDate" \
					-metadata DATE="$videoDate" \
					-metadata YEAR="$videoYear" \
					-metadata GENRE="$genre" \
					-metadata ARTIST="$lidarrArtistName" \
					-metadata ALBUMARTIST="$lidarrArtistName" \
					-metadata ENCODED_BY="lidarr-extended" \
					-attach "$videoDownloadPath/poster.jpg" -metadata:s:t mimetype=image/jpeg \
					"$videoDownloadPath/$videoFileName"
				chmod 666 "$videoDownloadPath/$videoFileName"
        if [ -f "$videoDownloadPath/poster.jpg" ]; then
          rm "$videoDownloadPath/poster.jpg"
        fi
			fi
			if [ -f "$videoDownloadPath/$videoFileName" ]; then
				if [ -f "$videoDownloadPath/${filenamenoext}.mkv" ]; then
					rm "$videoDownloadPath/${filenamenoext}.mkv"
				fi
			fi
		done


		if [ -f "$videoDownloadPath/$videoFileName" ]; then
			mv	"$videoDownloadPath/$videoFileName" "$videoPath/$lidarrArtistFolderNoDisambig/${videoFileName}"
			chmod 666 "$videoPath/$lidarrArtistFolderNoDisambig/${videoFileName}"
		fi
		exit
    done

done
exit

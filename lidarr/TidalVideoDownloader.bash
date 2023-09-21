#!/usr/bin/with-contenv bash
scriptVersion="1.9"
scriptName="TidalVideoDownloader"

#### Import Settings
source /config/extended.conf
#### Import Functions
source /config/extended/functions


verifyConfig () {
    videoContainer=mkv

	if [ "$enableVideo" != "true" ]; then
		log "Script is not enabled, enable by setting enableVideo to \"true\" by modifying the \"/config/extended.conf\" config file..."
		log "Sleeping (infinity)"
		sleep infinity
	fi
	
	if [ -z "$downloadPath" ]; then
		downloadPath="/config/extended/downloads"
	fi
	videoDownloadPath="$downloadPath/tidal/videos"
 	if [ -z "$videoScriptInterval" ]; then
  		videoScriptInterval="15m"
    	fi
	
	if [ -z "$videoPath" ]; then
		log "ERROR: videoPath is not configured via the \"/config/extended.conf\" config file..."
	 	log "Updated your \"/config/extended.conf\" file with the latest options, see: https://github.com/RandomNinjaAtk/arr-scripts/blob/main/lidarr/extended.conf"
		log "Sleeping (infinity)"
		sleep infinity
	fi
  
	if [ "$dlClientSource" == "tidal" ] || [ "$dlClientSource" == "both" ]; then
 		sleep 0.01
	else
		log "ERROR: Tidal is not enabled, set dlClientSource setting to either \"both\" or \"tidal\"..."
 		log "Sleeping (infinity)"
		sleep infinity
	fi
}

TidalClientSetup () {
	log "TIDAL :: Verifying tidal-dl configuration"
	if [ ! -f /config/xdg/.tidal-dl.json ]; then
		log "TIDAL :: No default config found, importing default config \"tidal.json\""
		if [ -f /config/extended/tidal-dl.json ]; then
			cp /config/extended/tidal-dl.json /config/xdg/.tidal-dl.json
			chmod 777 -R /config/xdg/
		fi
	fi
	
	tidal-dl -o "$videoDownloadPath"/incomplete 2>&1 | tee -a "/config/logs/$logFileName"
	tidalQuality=HiFi

	if [ ! -f /config/xdg/.tidal-dl.token.json ]; then
		#log "TIDAL :: ERROR :: Downgrade tidal-dl for workaround..."
		#pip3 install tidal-dl==2022.3.4.2 --no-cache-dir &>/dev/null
		log "TIDAL :: ERROR :: Loading client for required authentication, please authenticate, then exit the client..."
		NotifyWebhook "FatalError" "TIDAL requires authentication, please authenticate now (check logs)"
		tidal-dl 2>&1 | tee -a "/config/logs/$logFileName"
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
		tidal-dl -q Normal -o "$videoDownloadPath"/incomplete -l "$tidalClientTestDownloadId" 2>&1 | tee -a "/config/logs/$logFileName" 
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

AddFeaturedVideoArtists () {
    if [ "$addFeaturedVideoArtists" != "true" ]; then
        log "-----------------------------------------------------------------------------"
        log "Add Featured Music Video Artists to Lidarr :: DISABLED"    
        log "-----------------------------------------------------------------------------"
        return
    fi
    log "-----------------------------------------------------------------------------"
    log "Add Featured Music Video Artists to Lidarr :: ENABLED"    
    log "-----------------------------------------------------------------------------"
    lidarrArtistsData="$(curl -s "$arrUrl/api/v1/artist?apikey=${arrApiKey}" | jq -r ".[]")"
    artistTidalUrl=$(echo $lidarrArtistsData | jq -r '.links[] | select(.name=="tidal") | .url')
    videoArtists=$(ls /config/extended/cache/tidal-videos/)
    videoArtistsCount=$(ls /config/extended/cache/tidal-videos/ | wc -l)
    if [ "$videoArtistsCount" == "0" ]; then
        log "$videoArtistsCount Artists found for processing, skipping..."
        return
    fi
    loopCount=0
    for slug in $(echo $videoArtists); do
        loopCount=$(( $loopCount + 1))
        artistName="$(cat /config/extended/cache/tidal-videos/$slug)"
        if echo "$artistTidalUrl" | grep -i "tidal.com/artist/${slug}$" | read; then
            log "$loopCount of $videoArtistsCount :: $artistName :: Already added to Lidarr, skipping..."
            continue
        fi
        log "$loopCount of $videoArtistsCount :: $artistName :: Processing url :: https://tidal.com/artist/${slug}"

		artistNameEncoded="$(jq -R -r @uri <<<"$artistName")"
		lidarrArtistSearchData="$(curl -s "$arrUrl/api/v1/search?term=${artistNameEncoded}&apikey=${arrApiKey}")"
		lidarrArtistMatchedData=$(echo $lidarrArtistSearchData | jq -r ".[] | select(.artist) | select(.artist.links[].url | contains (\"tidal.com/artist/${slug}\"))" 2>/dev/null)
							
		if [ ! -z "$lidarrArtistMatchedData" ]; then
	        data="$lidarrArtistMatchedData"		
			artistName="$(echo "$data" | jq -r ".artist.artistName")"
			foreignId="$(echo "$data" | jq -r ".foreignId")"
        else
            log "$loopCount of $videoArtistsCount :: $artistName :: ERROR : Musicbrainz ID Not Found, skipping..."
            continue
        fi
		data=$(curl -s "$arrUrl/api/v1/rootFolder" -H "X-Api-Key: $arrApiKey" | jq -r ".[]")
		path="$(echo "$data" | jq -r ".path")"
		qualityProfileId="$(echo "$data" | jq -r ".defaultQualityProfileId")"
		metadataProfileId="$(echo "$data" | jq -r ".defaultMetadataProfileId")"
		data="{
			\"artistName\": \"$artistName\",
			\"foreignArtistId\": \"$foreignId\",
			\"qualityProfileId\": $qualityProfileId,
			\"metadataProfileId\": $metadataProfileId,
			\"monitored\":true,
			\"monitor\":\"all\",
			\"rootFolderPath\": \"$path\",
			\"addOptions\":{\"searchForMissingAlbums\":false}
			}"

		if echo "$lidarrArtistIds" | grep "^${foreignId}$" | read; then
			log "$loopCount of $videoArtistsCount :: $artistName :: Already in Lidarr ($foreignId), skipping..."
			continue
		fi
		log "$loopCount of $videoArtistsCount :: $artistName :: Adding $artistName to Lidarr ($foreignId)..."
		LidarrTaskStatusCheck
		lidarrAddArtist=$(curl -s "$arrUrl/api/v1/artist" -X POST -H 'Content-Type: application/json' -H "X-Api-Key: $arrApiKey" --data-raw "$data")
    done

}

LidarrTaskStatusCheck () {
	alerted=no
	until false
	do
		taskCount=$(curl -s "$arrUrl/api/v1/command?apikey=${arrApiKey}" | jq -r '.[] | select(.status=="started") | .name' | wc -l)
		if [ "$taskCount" -ge "1" ]; then
			if [ "$alerted" = "no" ]; then
				alerted=yes
				log "STATUS :: LIDARR BUSY :: Pausing/waiting for all active Lidarr tasks to end..."
			fi
			sleep 2
		else
			break
		fi
	done
}

VideoProcess () {
	lidarrArtists=$(wget --timeout=0 -q -O - "$arrUrl/api/v1/artist?apikey=$arrApiKey" | jq -r .[])
	lidarrArtistIds=$(echo $lidarrArtists | jq -r .id)
	lidarrArtistCount=$(echo "$lidarrArtistIds" | wc -l)
        processCount=0
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
		tidalVideoIdsCount=$(echo "$tidalVideoIds" | wc -l)
		tidalVideoProcessNumber=0
		
		for id in $(echo "$tidalVideoIds"); do
			tidalVideoProcessNumber=$(( $tidalVideoProcessNumber + 1 ))
			videoData=$(echo $tidalVideosData | jq -r "select(.id==$id)")
			videoTitle=$(echo $videoData | jq -r .title)
			videoTitleClean="$(echo "$videoTitle" | sed 's%/%-%g')"
			videoTitleClean="$(echo "$videoTitleClean" | sed -e "s/[:alpha:][:digit:]._' -/ /g" -e "s/  */ /g" | sed 's/^[.]*//' | sed  's/[.]*$//g' | sed  's/^ *//g' | sed 's/ *$//g')"
			videoExplicit=$(echo $videoData | jq -r .explicit)
			videoUrl="https://tidal.com/browse/video/$id"
			videoDate="$(echo "$videoData" | jq -r ".releaseDate")"
			videoDate="${videoDate:0:10}"
			videoYear="${videoDate:0:4}"
			videoImageId="$(echo "$videoData" | jq -r ".imageId")"
			videoImageIdFix="$(echo "$videoImageId" | sed "s/-/\//g")"
			videoThumbnailUrl="https://resources.tidal.com/images/$videoImageIdFix/750x500.jpg"
			videoSource="tidal"
			videoArtists="$(echo "$videoData" | jq -r ".artists[]")"
			videoArtistsIds="$(echo "$videoArtists" | jq -r ".id")"
			videoType=""
			log "$processCount/$lidarrArtistCount :: $lidarrArtistName :: $tidalVideoProcessNumber/$tidalVideoIdsCount :: $videoTitle ($id) :: Processing..."

			if echo "$videoTitle" | grep -i "official" | grep -i "video" | read; then
				log "$processCount/$lidarrArtistCount :: $lidarrArtistName :: $tidalVideoProcessNumber/$tidalVideoIdsCount :: $videoTitle ($id) :: Official Music Video Match Found!"
				videoType="-video"
			elif echo "$videoTitle" | grep -i "official" | grep -i "lyric" | read; then
				log "$processCount/$lidarrArtistCount :: $lidarrArtistName :: $tidalVideoProcessNumber/$tidalVideoIdsCount :: $videoTitle ($id) :: Official Lyric Video Match Found!"
				videoType="-lyrics"
			elif echo "$videoTitle" | grep -i "video" | grep -i "lyric" | read; then
				log "$processCount/$lidarrArtistCount :: $lidarrArtistName :: $tidalVideoProcessNumber/$tidalVideoIdsCount :: $videoTitle ($id) :: Official Lyric Video Match Found!"
				videoType="-lyrics"
			elif echo "$videoTitle" | grep -i "4k upgrade" | read; then
				log "$processCount/$lidarrArtistCount :: $lidarrArtistName :: $tidalVideoProcessNumber/$tidalVideoIdsCount :: $videoTitle ($id) :: 4K Upgrade Found!"
				videoType="-video" 
			elif echo "$videoTitle" | grep -i "\(.*live.*\)" | read; then
				log "$processCount/$lidarrArtistCount :: $lidarrArtistName :: $tidalVideoProcessNumber/$tidalVideoIdsCount :: $videoTitle ($id) :: Live Video Found!"
				videoType="-live"
			elif echo $lidarrArtistTrackData | grep -i "$videoTitle" | read; then
				log "$processCount/$lidarrArtistCount :: $lidarrArtistName :: $tidalVideoProcessNumber/$tidalVideoIdsCount :: $videoTitle ($id) :: Music Video Track Name Match Found!"
				videoType="-video" 
			else
				log "$processCount/$lidarrArtistCount :: $lidarrArtistName :: $tidalVideoProcessNumber/$tidalVideoIdsCount :: $videoTitle ($id) :: ERROR :: Unable to match!"
				continue
			fi

			videoFileName="${videoTitleClean}${videoType}.mkv"
			existingFileSize=""
			existingFile=""

			if [ -d "$videoPath/$lidarrArtistFolderNoDisambig" ]; then 
				existingFile="$(find "$videoPath/$lidarrArtistFolderNoDisambig" -type f -iname "${videoFileName}")"
				existingFileNfo="$(find "$videoPath/$lidarrArtistFolderNoDisambig" -type f -iname "${videoTitleClean}${videoType}.nfo")"
				existingFileJpg="$(find "$videoPath/$lidarrArtistFolderNoDisambig" -type f -iname "${videoTitleClean}${videoType}.jpg")"
			fi
			if [ -f "$existingFile" ]; then
				existingFileSize=$(stat -c "%s" "$existingFile")
			fi

			if [ -f "/config/extended/logs/tidal-video/$id" ]; then
				log "$processCount/$lidarrArtistCount :: $lidarrArtistName :: $tidalVideoProcessNumber/$tidalVideoIdsCount :: $videoTitle ($id) :: Previously Downloaded" 
				if [ -f "$existingFile" ]; then
					log "$processCount/$lidarrArtistCount :: $lidarrArtistName :: $tidalVideoProcessNumber/$tidalVideoIdsCount :: $videoTitle ($id) :: Previously Downloaded, skipping..."
					continue
				else
					log "$processCount/$lidarrArtistCount :: $lidarrArtistName :: $tidalVideoProcessNumber/$tidalVideoIdsCount :: $videoTitle ($id) :: Previously Downloaded file missing, re-downloading..."
				fi
			fi

			if [ ! -d "/config/extended/cache/tidal-videos" ]; then
				mkdir -p "/config/extended/cache/tidal-videos"
				chmod 777 "/config/extended/cache/tidal-videos"
			fi
			if [ ! -f "/config/extended/cache/tidal-videos/$tidalArtistIds" ]; then
				echo  -n "$lidarrArtistName" > "/config/extended/cache/tidal-videos/$tidalArtistIds"
			fi

			for videoArtistId in $(echo "$videoArtistsIds"); do
				videoArtistData=$(echo "$videoArtists" | jq -r "select(.id==$videoArtistId)")
				videoArtistName=$(echo "$videoArtistData" | jq -r .name)
				videoArtistType=$(echo "$videoArtistData" | jq -r .type)
				if [ ! -f "/config/extended/cache/tidal-videos/$videoArtistId" ]; then
					echo  -n "$videoArtistName" > "/config/extended/cache/tidal-videos/$videoArtistId"
				fi
			done

			

			if [ ! -d "$videoDownloadPath/incomplete" ]; then
				mkdir -p "$videoDownloadPath/incomplete"
			fi

			downloadFailed=false
			log "$processCount/$lidarrArtistCount :: $lidarrArtistName :: $tidalVideoProcessNumber/$tidalVideoIdsCount :: $videoTitle ($id) :: Downloading..."
			tidal-dl -r P1080 -o "$videoDownloadPath/incomplete" -l "$videoUrl" 2>&1 | tee -a "/config/logs/$logFileName"
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
					log "$processCount/$lidarrArtistCount :: $lidarrArtistName :: $tidalVideoProcessNumber/$tidalVideoIdsCount :: $videoTitle ($id) :: Download Complete!"
					chmod 666 "$videoDownloadPath/$filename"
					downloadFailed=false
				else
					log "$processCount/$lidarrArtistCount :: $lidarrArtistName :: $tidalVideoProcessNumber/$tidalVideoIdsCount :: $videoTitle ($id) :: ERROR :: Download failed!"
					downloadFailed=true
					break
				fi

				if [ "$videoDownloadPath/incomplete" ]; then
					rm -rf "$videoDownloadPath/incomplete"
				fi

				if python3 /usr/local/sma/manual.py --config "/config/extended/sma.ini" -i "$videoDownloadPath/$filename" -nt; then
					sleep 0.01
					log "$processCount/$lidarrArtistCount :: $lidarrArtistName :: $tidalVideoProcessNumber/$tidalVideoIdsCount :: $videoTitle ($id) :: Processed with SMA..."
					rm  /usr/local/sma/config/*log*
				else
					log "$processCount/$lidarrArtistCount :: $lidarrArtistName :: $tidalVideoProcessNumber/$tidalVideoIdsCount :: $videoTitle ($id) :: ERROR: SMA Processing Error"
					rm "$videoDownloadPath/$filename"
					log "$processCount/$lidarrArtistCount :: $lidarrArtistName :: $tidalVideoProcessNumber/$tidalVideoIdsCount :: $videoTitle ($id) :: INFO: deleted: $filename"
				fi

				if [ -f "$videoDownloadPath/${filenamenoext}.mkv" ]; then
					curl -s "$videoThumbnailUrl" -o "$videoDownloadPath/poster.jpg"
					log "$processCount/$lidarrArtistCount :: $lidarrArtistName :: $tidalVideoProcessNumber/$tidalVideoIdsCount :: $videoTitle ($id) :: Tagging file"
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
						"$videoDownloadPath/$videoFileName"  2>&1 | tee -a "/config/logs/$logFileName"
					chmod 666 "$videoDownloadPath/$videoFileName"
				fi
				if [ -f "$videoDownloadPath/$videoFileName" ]; then
					if [ -f "$videoDownloadPath/${filenamenoext}.mkv" ]; then
						rm "$videoDownloadPath/${filenamenoext}.mkv"
					fi
				fi
			done

			if [ "$downloadFailed" == "true" ]; then
				log "$processCount/$lidarrArtistCount :: $lidarrArtistName :: $tidalVideoProcessNumber/$tidalVideoIdsCount :: $videoTitle ($id) :: Skipping due to failed download..."
				continue
			fi

			downloadedFileSize=$(stat -c "%s" "$videoDownloadPath/$videoFileName")

			if [ -f "$existingFile" ]; then
				log "$processCount/$lidarrArtistCount :: $lidarrArtistName :: $tidalVideoProcessNumber/$tidalVideoIdsCount :: $videoTitle ($id) :: Logging completed download $id to: /config/extended/logs/tidal-video/$id"
				touch /config/extended/logs/tidal-video/$id
				chmod 666 "/config/extended/logs/tidal-video/$id"
				if [ $downloadedFileSize -lt $existingFileSize ]; then
					log "$processCount/$lidarrArtistCount :: $lidarrArtistName :: $tidalVideoProcessNumber/$tidalVideoIdsCount :: $videoTitle ($id) :: Downloaded file is smaller than existing file ($downloadedFileSize -lt $existingFileSize), skipping..."
					rm -rf "$videoDownloadPath"/*
					continue
				fi
				if [ $downloadedFileSize == $existingFileSize ]; then 
					log "$processCount/$lidarrArtistCount :: $lidarrArtistName :: $tidalVideoProcessNumber/$tidalVideoIdsCount :: $videoTitle ($id) :: Existing File is the same size as the download ($downloadedFileSize = $existingFileSize), skipping..."
					rm -rf "$videoDownloadPath"/*
					continue
				fi
				if [ $downloadedFileSize -gt $existingFileSize  ]; then
					log "$processCount/$lidarrArtistCount :: $lidarrArtistName :: $tidalVideoProcessNumber/$tidalVideoIdsCount :: $videoTitle ($id) :: Downloaded File is bigger than existing file ($downloadedFileSize -gt $existingFileSize), removing existing file to import the new file..."
					rm "$existingFile"

				fi
			fi

			log "$processCount/$lidarrArtistCount :: $lidarrArtistName :: $tidalVideoProcessNumber/$tidalVideoIdsCount :: $videoTitle ($id) :: Writing NFO"
			nfo="$videoDownloadPath/${videoTitleClean}${videoType}.nfo"
			if [ -f "$nfo" ]; then
				rm "$nfo"
			fi
			echo "<musicvideo>" >> "$nfo"
			echo "	<title>${videoTitle}</title>" >> "$nfo"
			echo "	<userrating/>" >> "$nfo"
			echo "	<track/>" >> "$nfo"
			echo "	<studio/>" >> "$nfo"
			if [ ! -z "$artistGenres" ]; then
				for genre in ${!artistGenres[@]}; do
					artistGenre="${artistGenres[$genre]}"
					echo "	<genre>$artistGenre</genre>" >> "$nfo"
				done
			fi
			echo "	<premiered/>" >> "$nfo"
			echo "	<year>$videoYear</year>" >> "$nfo"
			for videoArtistId in $(echo "$videoArtistsIds"); do
				videoArtistData=$(echo "$videoArtists" | jq -r "select(.id==$videoArtistId)")
				videoArtistName=$(echo "$videoArtistData" | jq -r .name)
				videoArtistType=$(echo "$videoArtistData" | jq -r .type)
				echo "	<artist>$videoArtistName</artist>" >> "$nfo"
			done
			echo "	<albumArtistCredits>" >> "$nfo"
			echo "		<artist>$lidarrArtistName</artist>" >> "$nfo"
			echo "		<musicBrainzArtistID>$lidarrArtistMusicbrainzId</musicBrainzArtistID>" >> "$nfo"
			echo "	</albumArtistCredits>" >> "$nfo"
			echo "	<thumb>${videoTitleClean}${videoType}.jpg</thumb>" >> "$nfo"
			echo "	<source>tidal</source>" >> "$nfo"
			echo "</musicvideo>" >> "$nfo"
			tidy -w 2000 -i -m -xml "$nfo" &>/dev/null
			chmod 666 "$nfo"



			if [ -f "$videoDownloadPath/$videoFileName" ]; then
				log "$processCount/$lidarrArtistCount :: $lidarrArtistName :: $tidalVideoProcessNumber/$tidalVideoIdsCount :: $videoTitle ($id) :: Moving Download to final destination"
				if [ ! -d "$videoPath/$lidarrArtistFolderNoDisambig" ]; then
					log "$processCount/$lidarrArtistCount :: $lidarrArtistName :: $tidalVideoProcessNumber/$tidalVideoIdsCount :: $videoTitle ($id) :: Creating Destination Directory \"$videoPath/$lidarrArtistFolderNoDisambig\""
					mkdir -p "$videoPath/$lidarrArtistFolderNoDisambig"
					chmod 777 "$videoPath/$lidarrArtistFolderNoDisambig"
				fi
				mv "$videoDownloadPath/$videoFileName" "$videoPath/$lidarrArtistFolderNoDisambig/${videoFileName}"
				log "$processCount/$lidarrArtistCount :: $lidarrArtistName :: $tidalVideoProcessNumber/$tidalVideoIdsCount :: $videoTitle ($id) :: Setting permissions"
				chmod 666 "$videoPath/$lidarrArtistFolderNoDisambig/${videoFileName}"
				if [ -f "$nfo" ]; then
					if [ -f "$existingFileNfo" ]; then
						log "$processCount/$lidarrArtistCount :: $lidarrArtistName :: $tidalVideoProcessNumber/$tidalVideoIdsCount :: $videoTitle ($id) :: Deleting existing video nfo"
						rm "$existingFileNfo"
					fi
					log "$processCount/$lidarrArtistCount :: $lidarrArtistName :: $tidalVideoProcessNumber/$tidalVideoIdsCount :: $videoTitle ($id) :: Moving video nfo to final destination"
					mv "$nfo" "$videoPath/$lidarrArtistFolderNoDisambig/${videoTitleClean}${videoType}.nfo"
					chmod 666 "$videoPath/$lidarrArtistFolderNoDisambig/${videoTitleClean}${videoType}.nfo"
				fi

				if [ -f "$videoDownloadPath/poster.jpg" ]; then
					if [ -f "$existingFileJpg" ]; then
						log "$processCount/$lidarrArtistCount :: $lidarrArtistName :: $tidalVideoProcessNumber/$tidalVideoIdsCount :: $videoTitle ($id) :: Deleting existing video jpg"
						rm "$existingFileJpg"
					fi
					log "$processCount/$lidarrArtistCount :: $lidarrArtistName :: $tidalVideoProcessNumber/$tidalVideoIdsCount :: $videoTitle ($id) :: Moving video poster to final destination"
					mv "$videoDownloadPath/poster.jpg" "$videoPath/$lidarrArtistFolderNoDisambig/${videoTitleClean}${videoType}.jpg"
					chmod 666 "$videoPath/$lidarrArtistFolderNoDisambig/${videoTitleClean}${videoType}.jpg"
				fi
			fi

			if [ ! -d /config/extended/logs/tidal-video ]; then
				mkdir -p /config/extended/logs/tidal-video 
				chmod 777 /config/extended/logs/tidal-video 
			fi
			log "$processCount/$lidarrArtistCount :: $lidarrArtistName :: $tidalVideoProcessNumber/$tidalVideoIdsCount :: $videoTitle ($id) :: Logging completed download $id to: /config/extended/logs/tidal-video/$id"
			touch /config/extended/logs/tidal-video/$id
			chmod 666 "/config/extended/logs/tidal-video/$id"
		done
	done
}

log "Starting Script...."
for (( ; ; )); do
	let i++
 	verifyConfig
	getArrAppInfo
	verifyApiAccess
	TidalClientSetup
	AddFeaturedVideoArtists
	VideoProcess 
	log "Script sleeping for $videoScriptInterval..."
	sleep $videoScriptInterval
done
exit

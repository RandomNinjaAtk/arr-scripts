#!/bin/bash
scriptVersion="2.2"
scriptName="Processor"
dockerPath="/config/logs"

##### VIDEO SCRIPT
videoLanguages="eng" # Default: eng :: Set to required language (this is a "," separated list of ISO 639-2 language codes)
defaultLanguage="English" # To use this porperly set the "default-language" Audio/Subtitle setting to the ISO 639-2 language code in the sma_defaultlang.ini file. The Language/word must match the exact spelling in the associated Arr App (ie: English = eng)
requireLanguageMatch="true" # true = enabled, disables/enables checking video audio/subtitle language based on videoLanguages setting
failVideosWithUnknownAudioTracks="true" # true = enabled, causes script to error out/fail download because unknown audio language tracks were found
requireSubs="true" # true = enabled, subtitles must be included or the download will be marked as failed

sonarrUrl="http://#:8989" # Set category in SABnzbd to: sonarr
sonarrApiKey="#" # Set category in SABnzbd to: sonarr
radarrUrl="http://#:7878" # Set category in SABnzbd to: radarr
radarrApiKey="#"  # Set category in SABnzbd to: radarr
radarr4kUrl="http://#:7879"  # Set category in SABnzbd to: radarr4k
radarr4kApiKey="#"  # Set category in SABnzbd to: radarr4k

set -e

installDependencies () {
  if apk --no-cache list | grep installed | grep mkvtoolnix | read; then
    log "Dependencies already installed, skipping..."
  else
    log "Installing script dependencies...."
    apk add  -U --update --no-cache \
      jq \
      xq \
      git \
      opus-tools \
      mkvtoolnix \
      ffmpeg
    log "done"
  fi
}

logfileSetup () {
  logFileName="$scriptName-$(date +"%Y_%m_%d_%I_%M_%p").txt"

  if find "$dockerPath" -type f -iname "$scriptName-*.txt" | read; then
    # Keep only the last 2 log files for 3 active log files at any given time...
    rm -f $(ls -1t $dockerPath/$scriptName-* | tail -n +5)
    # delete log files older than 5 days
    find "$dockerPath" -type f -iname "$scriptName-*.txt" -mtime +5 -delete
  fi
  
  if [ ! -f "$dockerPath/$logFileName" ]; then
    echo "" > "$dockerPath/$logFileName"
    chmod 666 "$dockerPath/$logFileName"
  fi
}

log () {
  m_time=`date "+%F %T"`
  echo $m_time" :: "$1
  echo $m_time" :: "$1 >> "$dockerPath/$logFileName"
}

VideoFileCheck () {
  log "Step - Video Check"
	# check for video files
	if find "$filePath" -type f -regex ".*/.*\.\(m4v\|wmv\|mkv\|mp4\|avi\)" | read; then
    log "Video Files Found, continuing..."
		sleep 0.1
	else
		log "ERROR: No video files found for processing"
		exit 1
	fi
}

VideoLanguageCheck () {
  log "Step - Language Check"
  if [ -f "/config/scripts/skip" ]; then
    rm "/config/scripts/skip"
  fi
  noremux="true"
	count=0
	fileCount=$(find "$filePath" -type f -regex ".*/.*\.\(m4v\|wmv\|mkv\|mp4\|avi\)" | wc -l)
	log "Processing ${fileCount} video files..."
	find "$filePath" -type f -regex ".*/.*\.\(m4v\|wmv\|mkv\|mp4\|avi\)" -print0 | while IFS= read -r -d '' file; do
		count=$(($count+1))
		baseFileName="${file%.*}"
		fileName="$(basename "$file")"
		extension="${fileName##*.}"
		log "$count of $fileCount :: Processing $fileName"
		videoData=$(ffprobe -v quiet -print_format json -show_streams "$file")
		videoAudioTracksCount=$(echo "${videoData}" | jq -r ".streams[] | select(.codec_type==\"audio\") | .index" | wc -l)
		videoUnknownAudioTracksNull=$(echo "${videoData}" | jq -r ".streams[] | select(.codec_type==\"audio\") | .tags.language")
		videoUnknownAudioTracksCount=$(echo "${videoData}" | jq -r ".streams[] | select(.codec_type==\"audio\") | select(.tags.language==\"und\") | .index" | wc -l)
		videoSubtitleTracksCount=$(echo "${videoData}" | jq -r ".streams[] | select(.codec_type==\"subtitle\") | .index" | wc -l)
		log "$count of $fileCount :: $videoAudioTracksCount Audio Tracks Found!"
		log "$count of $fileCount :: $videoSubtitleTracksCount Subtitle Tracks Found!"
		videoAudioLanguages=$(echo "${videoData}" | jq -r ".streams[] | select(.codec_type==\"audio\") | .tags.language")
		videoSubtitleLanguages=$(echo "${videoData}" | jq -r ".streams[] | select(.codec_type==\"subtitle\") | .tags.language")

		# Language Check
		log "$count of $fileCount :: Checking for preferred languages \"$videoLanguages\""
		preferredLanguage=false
		IFS=',' read -r -a filters <<< "$videoLanguages"
		for filter in "${filters[@]}"
		do
			videoAudioTracksLanguageCount=$(echo "${videoData}" | jq -r ".streams[] | select(.codec_type==\"audio\") | select(.tags.language==\"${filter}\") | .index" | wc -l)
			videoSubtitleTracksLanguageCount=$(echo "${videoData}" | jq -r ".streams[] | select(.codec_type==\"subtitle\") | select(.tags.language==\"${filter}\") | .index" | wc -l)
			log "$count of $fileCount :: $videoAudioTracksLanguageCount \"$filter\" Audio Tracks Found!"
			log "$count of $fileCount :: $videoSubtitleTracksLanguageCount \"$filter\" Subtitle Tracks Found!"			
			if [ "$preferredLanguage" == "false" ]; then
				if echo "$videoAudioLanguages" | grep -i "$filter" | read; then
					preferredLanguage=true
				elif echo "$videoSubtitleLanguages" | grep -i "$filter" | read; then
					preferredLanguage=true
				fi
			fi
		done

		if [ "$requireSubs" == "true" ]; then
			if [ "${requireLanguageMatch}" = "true" ]; then
			  if [ $videoSubtitleTracksLanguageCount -eq 0 ]; then
				  log "$count of $fileCount :: ERROR :: No subtitles found, requireSubs is enabled..."
					rm "$file" && log "INFO: deleted: $fileName"
			  fi
			elif [ $videoSubtitleTracksCount -eq 0 ]; then
			  log "$count of $fileCount :: ERROR :: No subtitles found, requireSubs is enabled..."
			  rm "$file" && log "INFO: deleted: $fileName"
			fi 
		fi

    if [ ! -f "$file" ]; then
      continue
    fi

		if [ "$failVideosWithUnknownAudioTracks" == "true" ]; then
		  if [ "$videoUnknownAudioTracksNull" == "null" ]; then
		   	log "$count of $fileCount :: ERROR :: $videoAudioTracksCount Unknown (null) Audio Language Tracks found, failing download and performing cleanup"
			  rm "$file" && log "INFO: deleted: $fileName"
		  elif [ $videoUnknownAudioTracksCount -ne 0 ]; then
        log "$count of $fileCount :: ERROR :: $videoUnknownAudioTracksCount Unknown Audio Language Tracks found, failing download and performing cleanup"
			  rm "$file" && log "INFO: deleted: $fileName"
		  fi
		fi

    if [ ! -f "$file" ]; then
      continue
    fi

		if [ "$preferredLanguage" == "false" ]; then
			if [ "$requireLanguageMatch" == "true" ]; then
				log "$count of $fileCount :: ERROR :: No matching languages found in $(($videoAudioTracksCount + $videoSubtitleTracksCount)) Audio/Subtitle tracks"
				rm "$file" && log "INFO: deleted: $fileName"
			fi
		fi

    if [ ! -f "$file" ]; then
      continue
    fi

    # Skip further processing when Number of Audio and Subtitle tracks match the preferred language 
    if [ $videoAudioTracksCount -eq $videoAudioTracksLanguageCount ]; then
      log "$count of $fileCount :: Audio Track Count Match (Total $videoAudioTracksCount vs Preferred $videoAudioTracksLanguageCount)" 
    else
      noremux="false"
    fi

    if [ $videoSubtitleTracksCount -eq $videoSubtitleTracksLanguageCount ]; then
      log "$count of $fileCount :: Subtitle Track Count Match (Total $videoSubtitleTracksCount vs Preferred $videoSubtitleTracksLanguageCount)" 
    else
      noremux="false"
    fi

    if [ "$noremux" == "true" ]; then
      log "$count of $fileCount :: Creating skip file"
      touch "/config/scripts/skip"
    elif [ -f "$filePath/$tempFile" ]; then
      log "$count of $fileCount :: Removing Source Temp File"
      rm "$filePath/$tempFile"
    fi

	done
}

MkvMerge () {
  log "Step - MKV Merge"
  count=0
  tempFile=""
	fileCount=$(find "$filePath" -type f -regex ".*/.*\.\(m4v\|wmv\|mkv\|mp4\|avi\)" | wc -l)
	log "Processing ${fileCount} video files with mkvmerge..."
	find "$filePath" -type f -regex ".*/.*\.\(m4v\|wmv\|mkv\|mp4\|avi\)" -print0 | while IFS= read -r -d '' file; do
		count=$(($count+1))
		baseFileName="${file%.*}"
		fileName="$(basename "$file")"
    fileNameNoExt="${fileName%.*}"
		extension="${fileName##*.}"
    tempFile="temp.$extension"
    newFile="$fileNameNoExt.mkv"
		log "$count of $fileCount :: Processing $fileName"
        if [ -f "$file" ]; then
          log "$count of $fileCount :: Renaming $fileName to $tempFile"
          mv "$file" "$filePath/$tempFile"
        fi
        if [ -f "$filePath/$tempFile" ]; then
          log "$count of $fileCount :: Dropping unwanted subtitles and converting to MKV ($tempFile ==> $newFile)"
          log "$count of $fileCount :: Keeping only \"$audioLang\" audio and \"$videoLanguages\" subtitle languages, droping all other audio/subtitle tracks..."
          mkvmerge -o "$filePath/$newFile" --audio-tracks $audioLang --subtitle-tracks $videoLanguages "$filePath/$tempFile" >> "$dockerPath/$logFileName"
          if [ -f "$filePath/$newFile" ]; then
              log "$count of $fileCount :: Conversion Complete"
          else
              log "$count of $fileCount :: ERROR :: File conversion failed..."
          fi
        fi
        if [ -f "$filePath/$newFile" ]; then
          if [ -f "$filePath/$tempFile" ]; then
              log "$count of $fileCount :: Removing Source Temp File"
              rm "$filePath/$tempFile"
          fi
        fi
    done

}

ArrWaitForTaskCompletion () {
  log "$count of $fileCount :: STATUS :: Checking ARR App Status"
  alerted=no
  until false
  do
    taskCount=$(curl -s "$arrUrl/api/v3/command?apikey=${arrApiKey}" | jq -r '.[] | select(.status=="started") | .name' | wc -l)
	arrDownloadTaskCount=$(curl -s "$arrUrl/api/v3/command?apikey=${arrApiKey}" | jq -r '.[] | select(.status=="started") | .name' | grep "ProcessMonitoredDownloads" | wc -l)
	if [ "$taskCount" -ge "3" ] || [ "$arrDownloadTaskCount" -ge "1" ]; then
	  if [ "$alerted" == "no" ]; then
		alerted="yes"
		log "$count of $fileCount :: STATUS :: ARR APP BUSY :: Pausing/waiting for all active Arr app tasks to end..."
	  else
	    log "$count of $fileCount :: STATUS :: ARR APP BUSY :: Waiting..."
	  fi
	  sleep 5
	else
	  break
	fi
  done
  log "$count of $fileCount :: STATUS :: Done"
  sleep 2
}

arrLanguage () {
  if [ "$arrItemLanguage" == "English" ]; then
    arrItemLang="en,$videoLanguages"
  elif [ "$arrItemLanguage" == "French" ]; then
    arrItemLang="fr,$videoLanguages"
  elif [ "$arrItemLanguage" == "Japanese" ]; then
    arrItemLang="ja,$videoLanguages"
  elif [ "$arrItemLanguage" == "German" ]; then
    arrItemLang="de,$videoLanguages"
  elif [ "$arrItemLanguage" == "Spanish" ]; then
    arrItemLang="es,$videoLanguages"
  elif [ "$arrItemLanguage" == "Chinese" ]; then
    arrItemLang="zh,$videoLanguages"
  elif [ "$arrItemLanguage" == "Telugu" ]; then
    arrItemLang="te,$videoLanguages"
  else
    log "ERROR :: Unconfigured Language ($arrItemLanguage), using default ($videoLanguages)"
    arrItemLang="$videoLanguages"
  fi
}

Cleaner () { 
  if find "$filePath" -type f -not -iname "*.mkv" | read; then
    log "Cleaner :: Removing all Non MKV Files"
    find "$filePath" -type f -not -iname "*.mkv" -delete
  fi
}

ArrDownloadInfo () {
    defaultLanguageMatch="false"
    log "Step - Getting Arr Download Information"
    if echo "$filePath" | grep "sonarr" | read; then
        arrUrl="$sonarrUrl" # Set category in SABnzbd to: sonarr
        arrApiKey="$sonarrApiKey" # Set category in SABnzbd to: sonarr
        arrQueueItemData=$(curl -s "$arrUrl/api/v3/queue?page=1&pageSize=75&sortDirection=ascending&sortKey=timeleft&includeUnknownSeriesItems=false&apikey=$arrApiKey" | jq -r --arg id "$downloadId" '.records[] | select(.downloadId==$id)')
        arrSeriesId="$(echo $arrQueueItemData | jq -r .seriesId | sort -u)"				
        if [ -z "$arrSeriesId" ]; then
            log "Could not get Series ID from Sonarr, skip..."
            tagging="-nt"
            onlineSourceId=""
            onlineData=""
        else
            arrSeriesCount=$(echo "$arrSeriesId" | wc -l)
            arrEpisodeId="$(echo $arrQueueItemData | jq -r .episodeId)"
            arrEpisodeCount=$(echo "$arrEpisodeId" | wc -l)
            arrSeriesData=$(curl -s "$arrUrl/api/v3/series/$arrSeriesId?apikey=$arrApiKey")
            onlineSourceId="$(echo "$arrSeriesData" | jq -r ".tvdbId")"
            arrItemLanguage="$(echo "$arrSeriesData" | jq -r ".originalLanguage.name")"
            log "Sonarr Show ID = $arrSeriesId :: Lanuage :: $arrItemLanguage"
            log "TVDB ID = $onlineSourceId"
            arrLanguage
            if [ "$arrItemLanguage" = "$defaultLanguage" ]; then
              log "Preferred Default Language Match!"
              audioLang="$videoLanguages"
            else
              audioLang="$arrItemLang"
            fi
        fi
    fi

    if echo "$filePath" | grep "radarr" | read; then
        if echo "$filePath" | grep "radarr" | read; then
            arrUrl="$radarrUrl" # Set category in SABnzbd to: radarr
            arrApiKey="$radarrApiKey" # Set category in SABnzbd to: radarr
        fi
        if echo "$filePath" | grep "radarr4k" | read; then
            arrUrl="$radarr4kUrl" # Set category in SABnzbd to: radarr4k
            arrApiKey="$radarr4kApiKey" # Set category in SABnzbd to: radarr4k
        fi
        arrItemId=$(curl -s "$arrUrl/api/v3/queue?page=1&pageSize=75&sortDirection=ascending&sortKey=timeleft&includeUnknownMovieItems=false&apikey=$arrApiKey" | jq -r --arg id "$downloadId" '.records[] | select(.downloadId==$id) | .movieId')
        arrItemData=$(curl -s "$arrUrl/api/v3/movie/$arrItemId?apikey=$arrApiKey")
        onlineSourceId="$(echo "$arrItemData" | jq -r ".tmdbId")"
        if [ -z "$onlineSourceId" ]; then
            log "Could not get Movie data from Radarr, skip..."
            tagging="-nt"
            onlineData=""
        else
            arrItemLanguage="$(echo "$arrItemData" | jq -r ".originalLanguage.name")"
            log "Radarr Movie ID = $arrItemId :: Language: $arrItemLanguage"
            log "TMDB ID = $onlineSourceId"
            onlineData="-tmdb $onlineSourceId"
            arrLanguage
            if [ "$arrItemLanguage" = "$defaultLanguage" ]; then
              log "Preferred Default Language Match!"
              audioLang="$videoLanguages"
            else
              audioLang="$arrItemLang"
            fi
        fi        
    fi
}

MAIN () {
  SECONDS=0
  logfileSetup
  filePath="$1"
  downloadId="$SAB_NZO_ID"
  log "Script: $scriptName :: Script Version :: $scriptVersion"
  installDependencies
  # log "$filePath :: $downloadId :: Processing"
  if find "$filePath" -type f -regex ".*/.*\.\(m4v\|wmv\|mkv\|mp4\|avi\)" | read; then
      VideoLanguageCheck
      VideoFileCheck
      if [ -f "/config/scripts/skip" ]; then
        log "Skip file found"
        skipRemux="true"
      else
        skipRemux="false"
      fi
      if find "$filePath" -type f -regex ".*/.*\.\(m4v\|wmv\|mp4\|avi\)" | read; then
        log "Non MKV files found, forcing remux"
        skipRemux="false"
      fi
      if [ "$skipRemux" == "false" ]; then
        ArrDownloadInfo
        MkvMerge
        VideoFileCheck
      else
        log "Files do not need remuxing, no further processing necessary..."
      fi
      if [ -f "/config/scripts/skip" ]; then
        rm "/config/scripts/skip"
      fi
      Cleaner
  fi

  duration=$SECONDS
  log "Post Processing Completed in $(($duration / 60 )) minutes and $(($duration % 60 )) seconds!"
}

MAIN "$1"
exit

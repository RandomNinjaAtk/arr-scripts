#!/bin/bash
scriptVersion="4.2"
scriptName="Processor"
dockerPath="/config/logs"

##### VIDEO SCRIPT
videoLanguages="eng" # Default: eng :: Set to required language (this is a "," separated list of ISO 639-2 language codes)
defaultLanguage="English" # To use this porperly set the "default-language" Audio/Subtitle setting to the ISO 639-2 language code in the sma_defaultlang.ini file. The Language/word must match the exact spelling in the associated Arr App (ie: English = eng)
requireLanguageMatch="true" # true = enabled, disables/enables checking video audio/subtitle language based on videoLanguages setting
failVideosWithUnknownAudioTracks="true" # true = enabled, causes script to error out/fail download because unknown audio language tracks were found
requireSubs="false" # true = enabled, subtitles must be included or the download will be marked as failed

sonarrUrl="http://:8989" # Set category in SABnzbd to: sonarr
sonarrApiKey="" # Set category in SABnzbd to: sonarr
radarrUrl="http://:7880" # Set category in SABnzbd to: radarr
radarrApiKey=""  # Set category in SABnzbd to: radarr

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
  noremuxOverride="false"
	count=0
	fileCount=$(find "$filePath" -type f -regex ".*/.*\.\(m4v\|wmv\|mkv\|mp4\|avi\)" | wc -l)
	log "Processing ${fileCount} video files..."
	find "$filePath" -type f -regex ".*/.*\.\(m4v\|wmv\|mkv\|mp4\|avi\)" -print0 | while IFS= read -r -d '' file; do
		count=$(($count+1))
		baseFileName="${file%.*}"
		fileName="$(basename "$file")"
		extension="${fileName##*.}"
		log "$count of $fileCount :: Processing $fileName"
		videoData=$(mkvmerge -J "$file")
    videoAudioTracksCount=$(echo "${videoData}" | jq -r '.tracks[] | select(.type=="audio") | .id' | wc -l)
    videoUnknownAudioTracksNull=$(echo "${videoData}" | jq -r '.tracks[] | select(.type=="audio") | .properties.language')
		videoUnknownAudioTracksCount=$(echo "${videoData}" | jq -r '.tracks[] | select(.type=="audio") | select(.properties.language=="und") | .id' | wc -l)
    videoSubtitleTracksCount=$(echo "${videoData}" | jq -r '.tracks[] | select(.type=="subtitles") | .id' | wc -l)
		log "$count of $fileCount :: $videoAudioTracksCount Audio Tracks Found!"
		log "$count of $fileCount :: $videoSubtitleTracksCount Subtitle Tracks Found!"
		videoAudioLanguages=$(echo "${videoData}" | jq -r '.tracks[] | select(.type=="audio") | .properties.language')
		videoSubtitleLanguages=$(echo "${videoData}" | jq -r '.tracks[] | select(.type=="subtitles") | .properties.language')

    # Language Check
		log "$count of $fileCount :: Checking for preferred languages \"$videoLanguages\""
		preferredLanguage=false
		IFS=',' read -r -a filters <<< "$videoLanguages"
		for filter in "${filters[@]}"
		do
      videoAudioTracksLanguageCount=$(echo "${videoData}" | jq -r --arg lang "$filter"  '.tracks[] | select(.type=="audio") | select(.properties.language==$lang) | .id' | wc -l)
      videoSubtitleTracksLanguageCount=$(echo "${videoData}" | jq -r --arg lang "$filter"  '.tracks[] | select(.type=="subtitles") | select(.properties.language==$lang) | .id' | wc -l)
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
      if [ "$videoUnknownAudioTracksNull" == "null" ] || [ $videoUnknownAudioTracksCount -ne 0 ]; then
        ArrDownloadInfo
        if [ "$arrItemLanguage" = "$defaultLanguage" ]; then
          if [ $videoAudioTracksCount -eq 1 ]; then
            preferredLanguage=true
            log "$count of $fileCount :: Only 1 Audio Track Detected, it is unknown but the download matches the defaultLanguage, so we're gonna assume it's just improperly tagged and skip failing the file..."
            if [ $videoSubtitleTracksCount -eq $videoSubtitleTracksLanguageCount ]; then
              noremuxOverride="true"
            else
              log "$count of $fileCount :: ERROR :: Subtitle track count missmatch, cannot remux due to unknown audio, failing download and performing cleanup..."
              rm "$file" && log "INFO: deleted: $fileName"
            fi
          fi
        else
          if [ "$videoUnknownAudioTracksNull" == "null" ] || [ $videoUnknownAudioTracksCount -ne 0 ]; then
            log "$count of $fileCount :: ERROR :: $videoAudioTracksCount Unknown (null) Audio Language Tracks found, failing download and performing cleanup..."
            rm "$file" && log "INFO: deleted: $fileName"
          fi
        fi
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
    if [ $videoAudioTracksCount -ne $videoAudioTracksLanguageCount ]; then
      if [ "$noremuxOverride" == "false" ] ; then
        log "$count of $fileCount :: Audio Track Count Missmatch (Total $videoAudioTracksCount vs Preferred $videoAudioTracksLanguageCount), forcing remux..."
        noremux="false"
      fi
    else
      log "$count of $fileCount :: Skipping ARR download information step because Audio Track count matches Preferred Track Count (Total $videoAudioTracksCount vs Preferred $videoAudioTracksLanguageCount)"
      touch "/config/scripts/arr-info"
    fi

    if [ $videoSubtitleTracksCount -ne $videoSubtitleTracksLanguageCount ]; then
      if [ "$noremuxOverride" == "false" ] ; then
        log "$count of $fileCount :: Subtitle Track Count Missmatch (Total $videoSubtitleTracksCount vs Preferred $videoSubtitleTracksLanguageCount), forcing remux..."
        noremux="false"
      fi
    fi

    if [ "$noremux" == "true" ] || [ "$noremuxOverride" == "true" ] ; then
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
        if [ "$1" = "true" ]; then
          log "$count of $fileCount :: Dropping unwanted subtitles and converting to MKV ($tempFile ==> $newFile)"
          log "$count of $fileCount :: Keeping only \"${audioLang}${videoLanguages},zxx\" audio and \"$videoLanguages\" subtitle languages, droping all other audio/subtitle tracks..."
          mkvmerge -o "$filePath/$newFile" --audio-tracks ${audioLang}${videoLanguages},zxx --subtitle-tracks $videoLanguages "$filePath/$tempFile"
        else
          mkvmerge -o "$filePath/$newFile" "$filePath/$tempFile"
        fi
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
      log "$count of $fileCount :: Validating remuxed file by checking for audio tracks" 
      newFileVideoData=$(mkvmerge -J "$filePath/$newFile")
      newFilevideoAudioTracksCount=$(echo "${newFileVideoData}" | jq -r '.tracks[] | select(.type=="audio") | .id' | wc -l)
      if [ $newFilevideoAudioTracksCount -eq 0 ]; then
        log "$count of $fileCount :: ERROR :: No audio tracks found afer remuxing, performing cleanup..."
				rm "$filePath/$newFile" && log "INFO: deleted: $newFile"
      else
        log "$count of $fileCount :: $newFilevideoAudioTracksCount Audio Tracks found!"
      fi
      log "$count of $fileCount :: Remux process complete!"
    done
}

ArrWaitForTaskCompletion () {
  refreshQueue=$(curl -s "$arrUrl/api/v3/command" -X POST -H 'Content-Type: application/json' -H "X-Api-Key: $arrApiKey" --data-raw '{"name":"RefreshMonitoredDownloads"}')
  log "Checking ARR App Status"
  alerted=no
  until false
  do
    taskCount=$(curl -s "$arrUrl/api/v3/command?apikey=${arrApiKey}" | jq -r '.[] | select(.status=="started") | .name' | wc -l)
    arrRefreshMonitoredDownloadTaskCount=$(curl -s "$arrUrl/api/v3/command?apikey=${arrApiKey}" | jq -r '.[] | select(.status=="started") | .name' | grep "RefreshMonitoredDownloads" | wc -l)
    if [ $arrRefreshMonitoredDownloadTaskCount -ge 1 ]; then
      if [ "$alerted" == "no" ]; then
        alerted="yes"
        log "STATUS :: ARR APP BUSY :: Pausing/waiting for all active Arr app tasks to end..."
        log "STATUS :: ARR APP BUSY :: Waiting..."
      fi
    else
      break
    fi
  done
  log "STATUS :: Done"
}

arrLanguage () {
  if [ "$arrItemLanguage" == "English" ]; then
    arrItemLang="en,"
  elif [ "$arrItemLanguage" == "French" ]; then
    arrItemLang="fr,"
  elif [ "$arrItemLanguage" == "Japanese" ]; then
    arrItemLang="ja,"
  elif [ "$arrItemLanguage" == "German" ]; then
    arrItemLang="de,"
  elif [ "$arrItemLanguage" == "Spanish" ]; then
    arrItemLang="es,"
  elif [ "$arrItemLanguage" == "Chinese" ]; then
    arrItemLang="zh,"
  elif [ "$arrItemLanguage" == "Telugu" ]; then
    arrItemLang="te,"
  elif [ "$arrItemLanguage" == "Turkish" ]; then
    arrItemLang="tr,"
  elif [ "$arrItemLanguage" == "Arabic" ]; then
    arrItemLang="ar,"
  elif [ "$arrItemLanguage" == "Bengali" ]; then
    arrItemLang="bn,"
  elif [ "$arrItemLanguage" == "Catalan" ]; then
    arrItemLang="ca,"
  elif [ "$arrItemLanguage" == "Croatian" ]; then
    arrItemLang="hr,"
  elif [ "$arrItemLanguage" == "Czech" ]; then
    arrItemLang="cs,"
  elif [ "$arrItemLanguage" == "Danish" ]; then
    arrItemLang="da,"
  elif [ "$arrItemLanguage" == "Dutch" ]; then
    arrItemLang="nl,"
  elif [ "$arrItemLanguage" == "Hindi" ]; then
    arrItemLang="hi,"
  elif [ "$arrItemLanguage" == "Hungarian" ]; then
    arrItemLang="hu,"
  elif [ "$arrItemLanguage" == "Icelandic" ]; then
    arrItemLang="is,"
  elif [ "$arrItemLanguage" == "Indonesian" ]; then
    arrItemLang="id,"
  elif [ "$arrItemLanguage" == "Italian" ]; then
    arrItemLang="it,"
  elif [ "$arrItemLanguage" == "Kannada" ]; then
    arrItemLang="kn,"
  elif [ "$arrItemLanguage" == "Korean" ]; then
    arrItemLang="ko,"
  elif [ "$arrItemLanguage" == "Latvian" ]; then
    arrItemLang="lv,"
  elif [ "$arrItemLanguage" == "Malayalam" ]; then
    arrItemLang="ml,"
  elif [ "$arrItemLanguage" == "Marathi" ]; then
    arrItemLang="mr,"
  elif [ "$arrItemLanguage" == "Norwegian" ]; then
    arrItemLang="no,"
  elif [ "$arrItemLanguage" == "Persian" ]; then
    arrItemLang="fa,"
  elif [ "$arrItemLanguage" == "Polish" ]; then
    arrItemLang="pl,"
  elif [ "$arrItemLanguage" == "Portuguese" ]; then
    arrItemLang="pt,"
  elif [ "$arrItemLanguage" == "Romanian" ]; then
    arrItemLang="ro,"
  elif [ "$arrItemLanguage" == "Russian" ]; then
    arrItemLang="ru,"
  elif [ "$arrItemLanguage" == "Serbian" ]; then
    arrItemLang="sr,"
  elif [ "$arrItemLanguage" == "Slovenian" ]; then
    arrItemLang="sl,"
  elif [ "$arrItemLanguage" == "Tagalog" ]; then
    arrItemLang="tl,"
  elif [ "$arrItemLanguage" == "Tamil" ]; then
    arrItemLang="ta,"
  elif [ "$arrItemLanguage" == "Thai" ]; then
    arrItemLang="th,"
  elif [ "$arrItemLanguage" == "Ukrainian" ]; then
    arrItemLang="uk,"
  elif [ "$arrItemLanguage" == "Vietnamese" ]; then
    arrItemLang="vi,"
  elif [ "$arrItemLanguage" == "Swedish" ]; then
    arrItemLang="sv,"
  elif [ "$arrItemLanguage" == "Finnish" ]; then
    arrItemLang="fi,"
  else
    log "ERROR :: Unconfigured Language ($arrItemLanguage), using default ($videoLanguages) only..."
    arrItemLang=""
  fi
}

arrApiKeySelect () {
  if echo "$filePath" | grep "sonarr" | read; then
    arrUrl="$sonarrUrl" # Set category in SABnzbd to: sonarr
    arrApiKey="$sonarrApiKey" # Set category in SABnzbd to: sonarr
  fi
  if echo "$filePath" | grep "radarr" | read; then
      arrUrl="$radarrUrl" # Set category in SABnzbd to: radarr
      arrApiKey="$radarrApiKey" # Set category in SABnzbd to: radarr
  fi
}

Cleaner () { 
  if find "$filePath" -type f -not -iname "*.mkv" | read; then
    log "Cleaner :: Removing all Non MKV Files"
    find "$filePath" -type f -not -iname "*.mkv" -delete
  fi
}

ArrDownloadInfo () {
  ArrWaitForTaskCompletion
  log "Step - Getting Arr Download Information"
  if echo "$filePath" | grep "sonarr" | read; then
      arrQueueItemData=$(curl -s "$arrUrl/api/v3/queue?page=1&pageSize=75&sortDirection=ascending&sortKey=timeleft&includeUnknownSeriesItems=false&apikey=$arrApiKey" | jq -r --arg id "$downloadId" '.records[] | select(.downloadId==$id)')
      arrSeriesId="$(echo $arrQueueItemData | jq -r .seriesId | sort -u)"				
      if [ -z "$arrSeriesId" ]; then
          log "Could not get Series ID from Sonarr, skip..."
          tagging="-nt"
          onlineSourceId=""
          onlineData=""
          audioLang=""
      else
          arrSeriesCount=$(echo "$arrSeriesId" | wc -l)
          arrEpisodeId="$(echo $arrQueueItemData | jq -r .episodeId)"
          arrEpisodeCount=$(echo "$arrEpisodeId" | wc -l)
          arrSeriesData=$(curl -s "$arrUrl/api/v3/series/$arrSeriesId?apikey=$arrApiKey")
          onlineSourceId="$(echo "$arrSeriesData" | jq -r ".tvdbId")"
          arrItemLanguage="$(echo "$arrSeriesData" | jq -r ".originalLanguage.name")"
          log "Sonarr Show ID = $arrSeriesId :: Lanuage :: $arrItemLanguage"
          log "TVDB ID = $onlineSourceId"
          if [ "$arrItemLanguage" = "$defaultLanguage" ]; then
            audioLang=""
          else
            arrLanguage
            audioLang="$arrItemLang"
          fi
      fi
  fi

  if echo "$filePath" | grep "radarr" | read; then
      arrItemId=$(curl -s "$arrUrl/api/v3/queue?page=1&pageSize=75&sortDirection=ascending&sortKey=timeleft&includeUnknownMovieItems=false&apikey=$arrApiKey" | jq -r --arg id "$downloadId" '.records[] | select(.downloadId==$id) | .movieId')
      arrItemData=$(curl -s "$arrUrl/api/v3/movie/$arrItemId?apikey=$arrApiKey")
      onlineSourceId="$(echo "$arrItemData" | jq -r ".tmdbId")"
      if [ -z "$onlineSourceId" ]; then
          log "Could not get Movie data from Radarr, skip..."
          tagging="-nt"
          onlineData=""
          audioLang=""
      else
          arrItemLanguage="$(echo "$arrItemData" | jq -r ".originalLanguage.name")"
          log "Radarr Movie ID = $arrItemId :: Language: $arrItemLanguage"
          log "TMDB ID = $onlineSourceId"
          onlineData="-tmdb $onlineSourceId"
          if [ "$arrItemLanguage" = "$defaultLanguage" ]; then
            audioLang=""
          else
            arrLanguage
            audioLang="$arrItemLang"
          fi
      fi        
  fi
  touch "/config/scripts/arr-info"
}

MAIN () {
  SECONDS=0
  logfileSetup
  touch "$dockerPath/$logFileName"
  exec &> >(tee -a "$dockerPath/$logFileName")
  filePath="$1"
  downloadId="$SAB_NZO_ID"
  skipRemux="false"
  log "Script: $scriptName :: Script Version :: $scriptVersion"
  installDependencies
  arrApiKeySelect
  # log "$filePath :: $downloadId :: Processing"
  if [ -f "/config/scripts/arr-info" ]; then
    rm "/config/scripts/arr-info"
  fi
  if find "$filePath" -type f -regex ".*/.*\.\(m4v\|wmv\|mkv\|mp4\|avi\)" | read; then
      if find "$filePath" -type f -regex ".*/.*\.\(m4v\|wmv\|mp4\|avi\)" | read; then
        MkvMerge "false"
        VideoFileCheck
      fi
      VideoLanguageCheck
      VideoFileCheck
      if [ -f "/config/scripts/skip" ]; then
        log "Skip file found"
        skipRemux="true"
        rm "/config/scripts/skip"
      fi
      if [ "$skipRemux" == "false" ]; then
        if [ ! -f "/config/scripts/arr-info" ]; then
          ArrDownloadInfo
        fi
        MkvMerge "true"
        VideoFileCheck
      else
        log "Files do not need further remuxing, no further processing necessary..."
      fi
      if [ -f "/config/scripts/arr-info" ]; then
        rm "/config/scripts/arr-info"
      fi
      Cleaner
  fi

  duration=$SECONDS
  log "Post Processing Completed in $(($duration / 60 )) minutes and $(($duration % 60 )) seconds!"
}

MAIN "$1"
exit

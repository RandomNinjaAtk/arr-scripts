#!/bin/bash
scriptVersion="3.6"
scriptName="Video"

#### Import Settings
source /config/extended.conf

log () {
  m_time=`date "+%F %T"`
  echo $m_time" :: $scriptName :: $scriptVersion :: "$1
}

set -e

# auto-clean up log file to reduce space usage
if [ -f "/config/scripts/video.txt" ]; then
  find /config/scripts -type f -name "video.txt" -size +1024k -delete
fi

touch "/config/scripts/video.txt"
exec &> >(tee -a "/config/scripts/video.txt")

function Configuration {
	log "SABnzbd Job: $jobname"
	log "SABnzbd Category: $category"
    log "SABnzbd Download ID: $downloadId"
	log "Script Versiion: $scriptVersion"
	log "CONFIGURATION VERIFICATION"
	log "##########################"
	log "Preferred Audio/Subtitle Languages: ${videoLanguages}"
	if [ "${requireLanguageMatch}" = "true" ]; then
		log "Require Matching Language :: Enabled"
	else
		log "Require Matching Language :: Disabled"
	fi
	
	if [ ${enableSma} = true ]; then
		log "Sickbeard MP4 Automator (SMA): ENABLED"
		if [ ${enableSmaTagging} = true ]; then
			tagging="-a"
			log "Sickbeard MP4 Automator (SMA): Tagging: ENABLED"
		else
			tagging="-nt"
			log "Sickbeard MP4 Automator (SMA): Tagging: DISABLED"
		fi
	else
		log "Sickbeard MP4 Automator (SMA): DISABLED"
	fi
	
	if [ -z "$enableSmaTagging" ]; then
		enableSmaTagging=FALSE
	fi

	if [ -z "$requireSubs" ]; then
	    log "Require Subtitles :: Disabled"
		requireSubs=FALSE
	else
        log "Require Subtitles :: Enabled"
	fi

    if [ -z "$failVideosWithUnknownAudioTracks" ]; then
	    log "Fail Videos with Unknown (language) Audio Tracks :: Disabled"
		failVideosWithUnknownAudioTracks=FALSE
	else
        log "Fail Videos with Unknown (language) Audio Tracks :: Enabled"
	fi
}

VideoLanguageCheck () {

	count=0
	fileCount=$(find "$1" -type f -regex ".*/.*\.\(m4v\|wmv\|mkv\|mp4\|avi\)" | wc -l)
	log "Processing ${fileCount} video files..."
	find "$1" -type f -regex ".*/.*\.\(m4v\|wmv\|mkv\|mp4\|avi\)" -print0 | while IFS= read -r -d '' file; do
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

        if [ ${enableSma} = true ]; then
			if [ "$smaProcessComplete" == "false" ]; then
				continue
			fi
		fi

		if [ "$requireSubs" == "true" ]; then
			if [ "${requireLanguageMatch}" = "true" ]; then
			   if [ $videoSubtitleTracksLanguageCount -eq 0 ]; then
					log "$count of $fileCount :: ERROR :: No subtitles found, requireSubs is enabled..."
					rm "$file" && log "INFO: deleted: $fileName"
			   elif [ $videoSubtitleTracksCount -ne $videoSubtitleTracksLanguageCount ]; then
			      log "$count of $fileCount :: ERROR :: Expected Subtitle count ($videoSubtitleTracksLanguageCount), $videoSubtitleTracksCount subtitles found..."
			      rm "$file" && log "INFO: deleted: $fileName"
			   fi
			elif [ $videoSubtitleTracksCount -eq 0 ]; then
			  log "$count of $fileCount :: ERROR :: No subtitles found, requireSubs is enabled..."
			  rm "$file" && log "INFO: deleted: $fileName"
			fi 
		fi

		if [ "$failVideosWithUnknownAudioTracks" == "true" ]; then
		  if [ "$videoUnknownAudioTracksNull" == "null" ]; then
		   	log "$count of $fileCount :: ERROR :: $videoAudioTracksCount Unknown (null) Audio Language Tracks found, failing download and performing cleanup"
			rm "$file" && log "INFO: deleted: $fileName"
   			return
		  elif [ $videoUnknownAudioTracksCount -ne 0 ]; then
            		log "$count of $fileCount :: ERROR :: $videoUnknownAudioTracksCount Unknown Audio Language Tracks found, failing download and performing cleanup"
			rm "$file" && log "INFO: deleted: $fileName"
   			return
		  fi
		fi

		if [ "$preferredLanguage" == "false" ]; then
			if [ "$requireLanguageMatch" == "true" ]; then
				log "$count of $fileCount :: ERROR :: No matching languages found in $(($videoAudioTracksCount + $videoSubtitleTracksCount)) Audio/Subtitle tracks"
				log "$count of $fileCount :: ERROR :: Disable "
				rm "$file" && log "INFO: deleted: $fileName"
			fi
		fi

		log "$count of $fileCount :: Processing complete for: ${fileName}!"
	done
}

VideoFileCheck () {
	# check for video files
	if find "$1" -type f -regex ".*/.*\.\(m4v\|wmv\|mkv\|mp4\|avi\)" | read; then
		sleep 0.1
	else
		log "ERROR: No video files found for processing"
		exit 1
	fi
}

DeleteLocalArtwork () {
	# check for local artwork files files
	if find "$1" -type f -regex ".*/.*\.\(jpg\|jpeg\|png\)" | read; then
	    log "Local Artwork found, removing local artwork"
	    find "$1" -type f -regex ".*/.*\.\(jpg\|jpeg\|png\)" -delete
		sleep 0.1
	else
		log "No local artwork found for removal"
	fi
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

VideoSmaProcess (){
	count=0
	fileCount=$(find "$1" -type f -regex ".*/.*\.\(m4v\|wmv\|mkv\|mp4\|avi\)" | wc -l)
	log "Processing ${fileCount} video files..."
	find "$1" -type f -regex ".*/.*\.\(m4v\|wmv\|mkv\|mp4\|avi\)" -print0 | while IFS= read -r -d '' file; do
		count=$(($count+1))
		baseFileName="${file%.*}"
		fileName="$(basename "$file")"
		extension="${fileName##*.}"
		log "$count of $fileCount :: Processing $fileName"
		if [ -f "$file" ]; then	
			if [ -f /config/scripts/sma/config/sma.log ]; then
				rm /config/scripts/sma/config/sma.log
			fi
			log "$count of $fileCount :: Processing with SMA..."
			if [ -f "/config/scripts/sma.ini" ]; then
			    onlineSourceId=""
			  	onlineData=""
				if [ ${enableSmaTagging} = true ]; then
					arrItemId=""
					arrItemData=""
					smaConfig=""
	 				arrItemLanguage=""
	                arrSeriesLanguage=""
					log "$count of $fileCount :: Getting Media ID"
					if echo $category | grep radarr | read; then
						log "$count of $fileCount :: Refreshing Radarr app Queue"
						refreshQueue=$(curl -s "$arrUrl/api/v3/command" -X POST -H 'Content-Type: application/json' -H "X-Api-Key: $arrApiKey" --data-raw '{"name":"RefreshMonitoredDownloads"}')
						ArrWaitForTaskCompletion
						log "$count of $fileCount :: Refresh complete"
						arrItemId=$(curl -s "$arrUrl/api/v3/queue?page=1&pageSize=75&sortDirection=ascending&sortKey=timeleft&includeUnknownMovieItems=false&apikey=$arrApiKey" | jq -r --arg id "$downloadId" '.records[] | select(.downloadId==$id) | .movieId')
						arrItemData=$(curl -s "$arrUrl/api/v3/movie/$arrItemId?apikey=$arrApiKey")
						onlineSourceId="$(echo "$arrItemData" | jq -r ".tmdbId")"
						if [ -z "$onlineSourceId" ]; then
							log "$count of $fileCount :: Could not get Movie data from Radarr, skip tagging..."
							tagging="-nt"
							onlineData=""
						else
						    arrItemLanguage="$(echo "$arrItemData" | jq -r ".originalLanguage.name")"
							log "$count of $fileCount :: Radarr Movie ID = $arrItemId :: Language: $arrItemLanguage"
							log "$count of $fileCount :: TMDB ID = $onlineSourceId"
							onlineData="-tmdb $onlineSourceId"
						fi

						if [ "$arrItemLanguage" = "$defaultLanguage" ]; then
							log "$count of $fileCount :: Default Language Match!"
							log "$count of $fileCount :: Any Unknown (Null) audio/subtitle tracks will be retagged as $defaultLanguage"
							smaConfig="/config/scripts/sma_defaultlang.ini"
						fi
						
					fi

					if echo $category | grep sonarr | read; then
						log "$count of $fileCount :: Refreshing Sonarr app Queue"
						refreshQueue=$(curl -s "$arrUrl/api/v3/command" -X POST -H 'Content-Type: application/json' -H "X-Api-Key: $arrApiKey" --data-raw '{"name":"RefreshMonitoredDownloads"}')
						ArrWaitForTaskCompletion
						log "$count of $fileCount :: Refresh complete"
						arrQueueItemData=$(curl -s "$arrUrl/api/v3/queue?page=1&pageSize=75&sortDirection=ascending&sortKey=timeleft&includeUnknownSeriesItems=false&apikey=$arrApiKey" | jq -r --arg id "$downloadId" '.records[] | select(.downloadId==$id)')
						arrSeriesId="$(echo $arrQueueItemData | jq -r .seriesId | sort -u)"				
						if [ -z "$arrSeriesId" ]; then
							log "$count of $fileCount :: Could not get Series ID from Sonarr, skip tagging..."
							tagging="-nt"
							onlineSourceId=""
							onlineData=""
						else
						    arrSeriesCount=$(echo "$arrSeriesId" | wc -l)
							arrEpisodeId="$(echo $arrQueueItemData | jq -r .episodeId)"
							arrEpisodeCount=$(echo "$arrEpisodeId" | wc -l)
							arrSeriesData=$(curl -s "$arrUrl/api/v3/series/$arrSeriesId?apikey=$arrApiKey")
							onlineSourceId="$(echo "$arrSeriesData" | jq -r ".tvdbId")"
							arrSeriesLanguage="$(echo "$arrSeriesData" | jq -r ".originalLanguage.name")"
							log "$count of $fileCount :: Sonarr Show ID = $arrSeriesId :: Lanuage :: $arrSeriesLanguage"
							log "$count of $fileCount :: TVDB ID = $onlineSourceId"						
							if [ $arrEpisodeCount -ge 2 ]; then
								log "$count of $fileCount :: Multi episode detected, skip tagging..."
								tagging="-nt"
								onlineSourceId=""
								onlineData=""
							else
								arrEpisodeData=$(curl -s "$arrUrl/api/v3/episode/$arrEpisodeId?apikey=$arrApiKey")
								seasonNumber="$(echo "$arrEpisodeData" | jq -r ".seasonNumber")"
								episodeNumber="$(echo "$arrEpisodeData" | jq -r ".episodeNumber")"
								onlineSource="-tvdb"
								onlineData="-tvdb $onlineSourceId -s $seasonNumber -e $episodeNumber"
							fi
							
							if [ "$arrSeriesLanguage" = "$defaultLanguage" ]; then
								log "$count of $fileCount :: Default Language Match!"
								log "$count of $fileCount :: Any Unknown (Null) audio/subtitle tracks will be retagged as $defaultLanguage"
								smaConfig="/config/scripts/sma_defaultlang.ini"
							fi
						fi
					fi
				fi

				if [ -z "$smaConfig" ]; then
					smaConfig="/config/scripts/sma.ini"
				fi

				if [ ! -f "$smaConfig" ]; then
					smaConfig="/config/scripts/sma.ini"
				fi

				# Manual run of Sickbeard MP4 Automator
				if python3 /config/scripts/sma/manual.py --config "$smaConfig" -i "$file" $tagging $onlineData; then
						log "$count of $fileCount :: Complete!"
				else
						log "$count of $fileCount :: ERROR :: SMA Processing Error"
						rm "$file" && log "INFO: deleted: $fileName"
				fi
			fi
		else
			log "$count of $fileCount :: ERROR :: SMA Processing Error"
			log "$count of $fileCount :: ERROR :: \"$smaConfig\" configuration file is missing..."
			rm "$file" && log "INFO: deleted: $fileName"
		fi
	done
	smaProcessComplete="true"
}

function Main {
	SECONDS=0
	error=0
	folderpath="$1"
	jobname="$3"
	category="$5"
	smaProcessComplete="false"
	downloadId="$SAB_NZO_ID"

	if [ "$category"  == "radarr" ]; then
	  arrUrl="$radarrArrUrl"
      arrApiKey="$radarrArrApiKey"
    fi
	if [ "$category"  == "radarr4k" ]; then
	  arrUrl="$radarr4kArrUrl"
      arrApiKey="$radarr4kArrApiKey"
    fi
	if [ "$category"  == "sonarr" ]; then
	  arrUrl="$sonarrArrUrl"
      arrApiKey="$sonarrArrApiKey"
    fi
	if [ "$category"  == "sonarr4k" ]; then
	  arrUrl="$sonarr4kArrUrl"
      arrApiKey="$sonarr4kArrApiKey"
    fi
	if [ "$category"  == "sonarranime" ]; then
	  arrUrl="$sonarranimeArrUrl"
      arrApiKey="$sonarranimeArrApiKey"
    fi

	Configuration
	VideoFileCheck "$folderpath"
	DeleteLocalArtwork "$folderpath"
	VideoLanguageCheck "$folderpath"
	VideoFileCheck "$folderpath"
	if [ ${enableSma} = true ]; then
		VideoSmaProcess "$folderpath" "$category"
	fi
	VideoFileCheck "$folderpath"
	VideoLanguageCheck "$folderpath"	
	VideoFileCheck "$folderpath"

	duration=$SECONDS
	echo "Post Processing Completed in $(($duration / 60 )) minutes and $(($duration % 60 )) seconds!"
}


Main "$@" 

exit $?

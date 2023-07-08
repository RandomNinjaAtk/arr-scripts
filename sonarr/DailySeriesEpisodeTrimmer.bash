#!/usr/bin/env bash
scriptVersion="1.0"

if [ -z "$arrUrl" ] || [ -z "$arrApiKey" ]; then
  arrUrlBase="$(cat /config/config.xml | xq | jq -r .Config.UrlBase)"
  if [ "$arrUrlBase" == "null" ]; then
    arrUrlBase=""
  else
    arrUrlBase="/$(echo "$arrUrlBase" | sed "s/\///g")"
  fi
  arrApiKey="$(cat /config/config.xml | xq | jq -r .Config.ApiKey)"
  arrPort="$(cat /config/config.xml | xq | jq -r .Config.Port)"
  arrUrl="http://127.0.0.1:${arrPort}${arrUrlBase}"
fi

log () {
  m_time=`date "+%F %T"`
  echo $m_time" :: DailySeriesEpisodeTrimmer :: $scriptVersion :: "$1
}

# auto-clean up log file to reduce space usage
if [ -f "/config/logs/DailySeriesEpisodeTrimmer.txt" ]; then
	find /config/logs -type f -name "DailySeriesEpisodeTrimmer.txt" -size +1024k -delete
fi

if [ ! -f "/config/logs/DailySeriesEpisodeTrimmer.txt" ]; then
    touch "/config/logs/DailySeriesEpisodeTrimmer.txt"
    chmod 666 "/config/logs/DailySeriesEpisodeTrimmer.txt"
fi
exec &> >(tee -a "/config/logs/DailySeriesEpisodeTrimmer.txt")

if [ "$sonarr_eventtype" == "Test" ]; then
	log "Tested"
	exit 0	
fi

seriesId=$sonarr_series_id
seriesData=$(curl -s "$arrUrl/api/v3/series/$seriesId?apikey=$arrApiKey")
seriesTitle=$(echo $seriesData | jq -r ".title")
seriesType=$(echo $seriesData | jq -r ".seriesType")
seriesEpisodeData=$(curl -s "$arrUrl/api/v3/episode?seriesId=$seriesId&apikey=$arrApiKey")
seriesEpisodeIds=$(echo "$seriesEpisodeData" | jq -r " . | sort_by(.airDate) | reverse | .[] | select(.hasFile==true) | .id")
seriesEpisodeIdsCount=$(echo "$seriesEpisodeIds" | wc -l)

# Verify series is marked as "daily" type by sonarr, skip if not...
if [ $seriesType != "daily" ]; then
	log "$seriesTitle (ID:$seriesId) :: TYPE :: $seriesType :: ERROR :: Non-daily series, skipping..."
	exit
fi

# Skip processing if less than 14 episodes were found to be downloaded
if [ $seriesEpisodeIdsCount -lt $maximumDailyEpisodes ]; then
	log "$seriesTitle (ID:$seriesId) :: TYPE :: $seriesType :: ERROR :: Series has not exceeded $maximumDailyEpisodes downloaded episodes ($seriesEpisodeIdsCount files found), skipping..."
	exit
fi

# Begin processing "daily" series type
if [ $seriesType == daily ]; then
	seriesEpisodeData=$(curl -s "$arrUrl/api/v3/episode?seriesId=$seriesId&apikey=$arrApiKey")
	seriesEpisodeIds=$(echo "$seriesEpisodeData"| jq -r " . | sort_by(.airDate) | reverse | .[] | select(.hasFile==true) | .id")
	processId=0
	seriesRefreshRequired=false
	for id in $seriesEpisodeIds; do
		processId=$(( $processId + 1 ))
		if [ $processId -gt $maximumDailyEpisodes ]; then
			episodeData=$(curl -s "http://localhost:8989/api/v3/episode/$id?apikey=$arrApiKey")
			episodeSeriesId=$(echo "$episodeData" | jq -r ".seriesId")
			episodeTitle=$(echo "$episodeData" | jq -r ".title")
			episodeSeasonNumber=$(echo "$episodeData" | jq -r ".seasonNumber")
			episodeNumber=$(echo "$episodeData" | jq -r ".episodeNumber")
			episodeAirDate=$(echo "$episodeData" | jq -r ".airDate")
			episodeFileId=$(echo "$episodeData" | jq -r ".episodeFileId")
			
			# Unmonitor downloaded episode if greater than 14 downloaded episodes
			log "$seriesTitle (ID:$episodeSeriesId) :: TYPE :: $seriesType :: S${episodeSeasonNumber}E${episodeNumber} :: $episodeAirDate :: $episodeTitle :: Unmonitored Episode ID :: $id"
			umonitorEpisode=$(curl -s "$arrUrl/api/v3/episode/monitor?apikey=$arrApiKey" -X PUT --data-raw "{\"episodeIds\":[$id],\"monitored\":false}")			
			
			# Delete downloaded episode if greater than 14 downloaded episodes
			log "$seriesTitle (ID:$episodeSeriesId) :: TYPE :: $seriesType :: S${episodeSeasonNumber}E${episodeNumber} :: $episodeAirDate :: $episodeTitle :: Deleted File ID :: $episodeFileId"
			deleteFile=$(curl -s "$arrUrl/api/v3/episodefile/$episodeFileId?apikey=$arrApiKey" -X DELETE)
			seriesRefreshRequired=true
		else
			# Skip if less than required 14 downloaded episodes exist
			log "$seriesTitle (ID:$episodeSeriesId) :: TYPE ::  $seriesType :: Skipping Episode ID :: $id"
		fi
	done
	if [ "$seriesRefreshRequired" = "true" ]; then
		# Refresh Series after changes
		log "$seriesTitle (ID:$episodeSeriesId) :: TYPE :: $seriesType :: Refresh Series"
		refreshSeries=$(curl -s "$arrUrl/api/v3/command?apikey=$arrApiKey" -X POST --data-raw "{\"name\":\"RefreshSeries\",\"seriesId\":$episodeSeriesId}")
	fi
fi

exit

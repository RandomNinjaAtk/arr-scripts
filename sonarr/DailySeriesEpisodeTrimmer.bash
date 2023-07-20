#!/usr/bin/env bash
scriptVersion="1.2"
scriptName="DailySeriesEpisodeTrimmer"

#### Import Settings
source /config/extended.conf
#### Import Functions
source /config/extended/functions
#### Create Log File
logfileSetup
#### Check Arr App
getArrAppInfo
verifyApiAccess

if [ "$enableDailySeriesEpisodeTrimmer" != "true" ]; then
	log "Script is not enabled, enable by setting enableDailySeriesEpisodeTrimmer to \"true\" by modifying the \"/config/extended.conf\" config file..."
	log "Sleeping (infinity)"
	sleep infinity
fi

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

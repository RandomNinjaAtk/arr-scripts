#!/usr/bin/env bash
scriptVersion="1.5"
scriptName="SeriesEpisodeTrimmer"

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
seriesTags=$(echo $seriesData | jq -r ".tags[]")
seriesEpisodeData=$(curl -s "$arrUrl/api/v3/episode?seriesId=$seriesId&apikey=$arrApiKey")
seriesEpisodeIds=$(echo "$seriesEpisodeData" | jq -r " . | sort_by(.airDate) | reverse | .[] | select(.hasFile==true) | .id")
seriesEpisodeIdsCount=$(echo "$seriesEpisodeIds" | wc -l)

# If sonarr series is tagged, match via tag to support series that are not considered daily
if [ -z "$sonarrSeriesEpisodeTrimmerTag" ]; then
	tagMatch="false"
else
	tagMatch="false"
	for tagId in $seriesTags; do
		tagLabel="$(curl -s "$arrUrl/api/v3/tag/$tagId?apikey=$arrApiKey" | jq -r ".label")"
		if  [ "$sonarrSeriesEpisodeTrimmerTag" == "$tagLabel" ]; then
			tagMatch="true"
			break
		fi
	done
fi

# Verify series is marked as "daily" type by sonarr, skip if not...
if [ $seriesType != "daily" ] && [ "$tagMatch" == "false" ]; then
	log "$seriesTitle (ID:$seriesId) :: ERROR :: Series does not match TYPE: Daily or TAG: $sonarrSeriesEpisodeTrimmerTag, skipping..."
	exit
fi

# If non-daily series, set maximum episode count to match latest season total episode count
if [ $seriesType != "daily" ]; then
  maximumDailyEpisodes=$(echo "$seriesData" | jq -r ".seasons | sort_by(.seasonNumber) | reverse | .[].statistics.totalEpisodeCount" | head -n1)
fi

# Skip processing if less than the maximumDailyEpisodes setting were found to be downloaded
if [ $seriesEpisodeIdsCount -lt $maximumDailyEpisodes ]; then
	log "$seriesTitle (ID:$seriesId) :: ERROR :: Series has not exceeded $maximumDailyEpisodes downloaded episodes ($seriesEpisodeIdsCount files found), skipping..."
	exit
fi

# Begin processing "daily" series type
seriesEpisodeData=$(curl -s "$arrUrl/api/v3/episode?seriesId=$seriesId&apikey=$arrApiKey")
seriesEpisodeIds=$(echo "$seriesEpisodeData"| jq -r " . | sort_by(.airDate) | reverse | .[] | select(.hasFile==true) | .id")
processId=0
seriesRefreshRequired=false
for id in $seriesEpisodeIds; do
	processId=$(( $processId + 1 ))
	episodeData=$(curl -s "http://localhost:8989/api/v3/episode/$id?apikey=$arrApiKey")
	episodeSeriesId=$(echo "$episodeData" | jq -r ".seriesId")
	if [ $processId -gt $maximumDailyEpisodes ]; then
		episodeTitle=$(echo "$episodeData" | jq -r ".title")
		episodeSeasonNumber=$(echo "$episodeData" | jq -r ".seasonNumber")
		episodeNumber=$(echo "$episodeData" | jq -r ".episodeNumber")
		episodeAirDate=$(echo "$episodeData" | jq -r ".airDate")
		episodeFileId=$(echo "$episodeData" | jq -r ".episodeFileId")
		
		# Unmonitor downloaded episode if greater than 14 downloaded episodes
		log "$seriesTitle (ID:$episodeSeriesId) :: S${episodeSeasonNumber}E${episodeNumber} :: $episodeTitle :: Unmonitored Episode ID :: $id"
		umonitorEpisode=$(curl -s "$arrUrl/api/v3/episode/monitor?apikey=$arrApiKey" -X PUT -H 'Content-Type: application/json'  --data-raw "{\"episodeIds\":[$id],\"monitored\":false}")

		# Delete downloaded episode if greater than 14 downloaded episodes
		log "$seriesTitle (ID:$episodeSeriesId) :: S${episodeSeasonNumber}E${episodeNumber} :: $episodeTitle :: Deleted File ID :: $episodeFileId"
		deleteFile=$(curl -s "$arrUrl/api/v3/episodefile/$episodeFileId?apikey=$arrApiKey" -X DELETE)
		seriesRefreshRequired=true
	else
		# Skip if less than required 14 downloaded episodes exist
		log "$seriesTitle (ID:$episodeSeriesId) :: Skipping Episode ID :: $id"
	fi
done
if [ "$seriesRefreshRequired" = "true" ]; then
	# Refresh Series after changes
	log "$seriesTitle (ID:$episodeSeriesId) :: Refresh Series"
	refreshSeries=$(curl -s "$arrUrl/api/v3/command?apikey=$arrApiKey" -X POST --data-raw "{\"name\":\"RefreshSeries\",\"seriesId\":$episodeSeriesId}")
fi
exit

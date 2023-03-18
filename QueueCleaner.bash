#!/usr/bin/env bash
scriptVersion="1.0.2"

######## Settings
scriptInterval="15m"

######## Package dependencies installation
apk add -U --update --no-cache curl jq python3-dev py3-pip &>/dev/null
pip install --upgrade --no-cache-dir -U yq &>/dev/null

# Logging output function
log () {
  m_time=`date "+%F %T"`
  echo $m_time" :: QueueCleaner :: $scriptVersion :: "$1
}

QueueCleanerProcess () {
  # Get Arr App information
  if [ -z "$arrUrl" ] || [ -z "$arrApiKey" ]; then
    arrUrlBase="$(cat /config/config.xml | xq | jq -r .Config.UrlBase)"
    if [ "$arrUrlBase" == "null" ]; then
      arrUrlBase=""
    else
      arrUrlBase="/$(echo "$arrUrlBase" | sed "s/\///g")"
    fi
    arrName="$(cat /config/config.xml | xq | jq -r .Config.InstanceName)"
    arrApiKey="$(cat /config/config.xml | xq | jq -r .Config.ApiKey)"
    arrPort="$(cat /config/config.xml | xq | jq -r .Config.Port)"
    arrUrl="http://127.0.0.1:${arrPort}${arrUrlBase}"
  fi

  # auto-clean up log file to reduce space usage
  if [ -f "/config/logs/QueueCleaner.txt" ]; then
    find /config/logs -type f -name "QueueCleaner.txt" -size +1024k -delete
  fi

  touch "/config/logs/QueueCleaner.txt"
  chmod 666 "/config/logs/QueueCleaner.txt"
  exec &> >(tee -a "/config/logs/QueueCleaner.txt")

  verifyApiAccess

  if [ "$arrName" == "Sonarr" ]; then
    arrQueueData="$(curl -s "$arrUrl/api/v3/queue?page=1&pagesize=200&sortDirection=descending&sortKey=progress&includeUnknownSeriesItems=true&apikey=${arrApiKey}" | jq -r .records[])"
  fi

  if [ "$arrName" == "Radarr" ]; then
     arrQueueData="$(curl -s "$arrUrl/api/v3/queue?page=1&pagesize=200&sortDirection=descending&sortKey=progress&includeUnknownMovieItems=true&apikey=${arrApiKey}" | jq -r .records[])"
  fi

  if [ "$arrName" == "Lidarr" ]; then
    arrQueueData="$(curl -s "$arrUrl/api/v1/queue?page=1&pagesize=200&sortDirection=descending&sortKey=progress&includeUnknownArtistItems=true&apikey=${arrApiKey}" | jq -r .records[])"
  fi

  arrQueueCompletedIds=$(echo "$arrQueueData" | jq -r 'select(.status=="completed") | select(.trackedDownloadStatus=="warning") | .id')
  arrQueueIdsCompletedCount=$(echo "$arrQueueData" | jq -r 'select(.status=="completed") | select(.trackedDownloadStatus=="warning") | .id' | wc -l)
  arrQueueFailedIds=$(echo "$arrQueueData" | jq -r 'select(.status=="failed") | .id')
  arrQueueIdsFailedCount=$(echo "$arrQueueData" | jq -r 'select(.status=="failed") | .id' | wc -l)
  arrQueuedIds=$(echo "$arrQueueCompletedIds"; echo "$arrQueueFailedIds")
  arrQueueIdsCount=$(( $arrQueueIdsCompletedCount + $arrQueueIdsFailedCount ))

  if [ $arrQueueIdsCount -eq 0 ]; then
    log "No items in queue to clean up..."
  else
    for queueId in $(echo $arrQueuedIds); do
      arrQueueItemData="$(echo "$arrQueueData" | jq -r "select(.id==$queueId)")"
      arrQueueItemTitle="$(echo "$arrQueueItemData" | jq -r .title)"
      if [ "$arrName" == "Sonarr" ]; then
        arrEpisodeId="$(echo "$arrQueueItemData" | jq -r .episodeId)"
        arrEpisodeData="$(curl -s "$arrUrl/api/v3/episode/$arrEpisodeId?apikey=${arrApiKey}")"
        arrEpisodeTitle="$(echo "$arrEpisodeData" | jq -r .title)"
        arrEpisodeSeriesId="$(echo "$arrEpisodeData" | jq -r .seriesId)"
        if [ "$arrEpisodeTitle" == "TBA" ]; then
          log "$queueId ($arrQueueItemTitle) :: ERROR :: Episode title is \"$arrEpisodeTitle\" and prevents auto-import, refreshing series..."
          refreshSeries=$(curl -s "$arrUrl/api/v3/command" -X POST -H 'Content-Type: application/json' -H "X-Api-Key: $arrApiKey" --data-raw "{\"name\":\"RefreshSeries\",\"seriesId\":$arrEpisodeSeriesId}")
          continue
        fi
      fi
      log "$queueId ($arrQueueItemTitle) :: Removing Failed Queue Item from $arrName..."
      deleteItem=$(curl -sX DELETE "$arrUrl/api/v3/queue/$queueId?removeFromClient=true&blocklist=true&apikey=${arrApiKey}")
    done
  fi
}

verifyApiAccess () {
	until false
	do
		arrApiTest=""
		arrApiVersion=""
		if [ "$arrName" == "Sonarr" ] || [ "$arrName" == "Radarr" ]; then
		  arrApiVersion="v3"
		elif [ "$arrName" == "Lidarr" ]; then
		  arrApiVersion="v1"
		fi
		arrApiTest=$(curl -s "$arrUrl/api/$arrApiVersion/system/status?apikey=$arrApiKey" | jq -r .instanceName)
		if [ "$arrApiTest" == "$arrName" ]; then
			arrVersion=$(curl -s "$arrUrl/api/$arrApiVersion/system/status?apikey=$arrApiKey" | jq -r .version)
			log "$arrName Version: $arrVersion"
			break
		else
			log "$arrName is not ready, sleeping until valid response..."
			sleep 1
		fi
	done
}

if [ "$enableQueueCleaner" == "false" ]; then
  log "ERROR :: Script disabled, exiting..."
  exit
fi

arrName="$(cat /config/config.xml | xq | jq -r .Config.InstanceName)"
if [ "$arrName" == "Sonarr" ] || [ "$arrName" == "Radarr" ] || [ "$arrName" == "Lidarr" ]; then
    for (( ; ; )); do
        let i++
        QueueCleanerProcess
        log "Processing complete, sleeping for $scriptInterval..."
        sleep $scriptInterval
    done
else
    log "ERROR :: Arr app not detected, exiting..."
fi

exit

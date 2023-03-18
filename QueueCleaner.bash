#!/usr/bin/env bash
scriptVersion="1.0.0"

######## Dependancy Installation
pip install --upgrade --no-cache-dir -U yq

log () {
  m_time=`date "+%F %T"`
  echo $m_time" :: QueueCleaner :: $scriptVersion :: "$1
}

QueueCleanerProcess () {
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
      log "Removing Failed Queue Item ID: $queueId ($arrQueueItemTitle) from Radarr..."
      deleteItem=$(curl -sX DELETE "$arrUrl/api/v3/queue/$queueId?removeFromClient=true&blocklist=true&apikey=${arrApiKey}")
    done
  fi
}

log "Waiting for $arrName to startup, sleeping for 2 minutes..."
sleep 2m
log "Starting Script...."
for (( ; ; )); do
	let i++
	   
	QueueCleanerProcess
	
	log "Script sleeping for 15 minutes..."
	sleep 15m
done

exit

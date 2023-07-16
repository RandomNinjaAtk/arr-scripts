#!/usr/bin/with-contenv bash
scriptVersion="0.1"
scriptName="UnmappedFilesCleaner"

log () {
  m_time=`date "+%F %T"`
  echo $m_time" :: $scriptName :: $scriptVersion :: "$1
}

logfileSetup () {
  # auto-clean up log file to reduce space usage
  if [ -f "/config/logs/$scriptName.txt" ]; then
    find /config/logs -type f -name "$scriptName.txt" -size +5000k -delete
    sleep 0.01
  fi
  touch "/config/logs/$scriptName.txt"
  exec &> >(tee -a "/config/logs/$scriptName.txt")
  chmod 666 "/config/logs/$scriptName.txt"
}

verifyConfig () {
  #### Import Settings
  source /config/extended.conf

  if [ "$enableUnmappedFilesCleaner" != "true" ]; then
    log "Script is not enabled, enable by setting enableUnmappedFilesCleaner to \"true\" by modifying the \"/config/extended.conf\" config file..."
    log "Sleeping (infinity)"
    sleep infinity
  fi

  if [ -z "$unmappedFilesCleanerScriptInterval" ]; then
    unmappedFilesCleanerScriptInterval="15m"
  fi
}

getArrAppInfo () {
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
}

verifyApiAccess () {
  until false
  do
    arrApiTest=""
    arrApiVersion=""
    if [ "$arrPort" == "8989" ] || [ "$arrPort" == "7878" ]; then
      arrApiVersion="v3"
    elif [ "$arrPort" == "8686" ] || [ "$arrPort" == "8787" ]; then
      arrApiVersion="v1"
    fi
    arrApiTest=$(curl -s "$arrUrl/api/$arrApiVersion/system/status?apikey=$arrApiKey" | jq -r .instanceName)
    if [ "$arrApiTest" == "$arrName" ]; then
      break
    else
      log "$arrName is not ready, sleeping until valid response..."
      sleep 1
    fi
  done
}


curl  "$arrUrl/api/v1/trackFile?unmapped=true" -H 'Content-Type: application/json' -H "X-Api-Key: $arrApiKey"

#!/usr/bin/env bash
scriptVersion="1.0"
scriptName="TdarrScan"

#### Import Settings
source /config/extended.conf

log () {
  m_time=`date "+%F %T"`
  echo $m_time" :: $scriptName :: $scriptVersion :: "$1
}

notfidedBy="Sonarr"
arrEventType="$sonarr_eventtype"
contentPath="$(dirname "$sonarr_episodefile_path")"
file="$sonarr_episodefile_path"

# Clean up old logs greater than 1MB
if [ -f "/config/logs/$scriptName.txt" ]; then
	find /config/logs -type f -name "$scriptName.txt" -size +1024k -delete
fi

# Create log file if it doesn't exist
if [ ! -f "/config/logs/$scriptName.txt" ]; then
    touch "/config/logs/$scriptName.txt"
    chmod 777 "/config/logs/$scriptName.txt"
fi
exec &> >(tee -a "/config/logs/$scriptName.txt")

if [ -z "$tdarrUrl" ]; then
  log "$notfidedBy :: tdarrUrl is not set, skipping..."
  exit
fi

# Validate connection
TdarrValidateConnection () {
  tdarrVersion=$(curl -m 5 -s "$tdarrUrl/api/v2/status" | jq -r '.version')
  if [ "$tdarrVersion" == "" ]; then
    log "ERROR :: Cannot communicate with Tdarr"
    log "ERROR :: Please check your tdarrUrl"
    log "ERROR :: Configured tdarrUrl \"$tdarrUrl\""
    log "ERROR :: Exiting..."
    exit 1
  else
    log "Tdarr Connection Established, version: $tdarrVersion"
  fi
}

# Test connection
if [ "$arrEventType" == "Test" ]; then
	TdarrValidateConnection
	log "$notfidedBy :: Tested Successfully"
	exit 0
fi

TdarrValidateConnection

payload="{ \"data\": { \"folderPath\": \"$contentPath\" }}"

# Check if path exists in Tdarr
if [ $(curl -s -X POST "$tdarrUrl/api/v2/verify-folder-exists" -H "Content-Type: application/json" -d "$payload" 2>/dev/null) == "false" ]; then
  log "$notfidedBy :: ERROR: Path \"$contentPath\" does not exist in Tdarr"
  exit 1
fi

payload="{ \"data\": { \"scanConfig\": {\"dbID\": \"$tdarrDbID\", \"arrayOrPath\": [\"$file\"], \"mode\": \"scanFolderWatcher\" }}}"

# Send scan request to Tdarr
if [[ -n "$arrEventType" && "$arrEventType" != "Test" ]]; then
  curl -s -X POST "$tdarrUrl/api/v2/scan-files" -H "Content-Type: application/json" -d "$payload" >/dev/null 2>&1
  if [ $? -eq 0 ]; then
    log "$notfidedBy :: Scan request sent to Tdarr for \"$contentPath\" with dbID \"$tdarrDbID\""
  else
    log "$notfidedBy :: ERROR: Failed to send scan request to Tdarr for \"$contentPath\" with dbID \"$tdarrDbID\""
  fi
fi

exit

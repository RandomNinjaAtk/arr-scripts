log () {
  m_time=`date "+%F %T"`
  echo $m_time" :: $scriptName :: $scriptVersion :: "$1
  echo $m_time" :: $scriptName :: $scriptVersion :: "$1 >> "/config/logs/$logFileName"
}

logfileSetup () {
  logFileName="$scriptName-$(date +"%Y_%m_%d_%I_%M_%p").txt"

  # Keep only the last 2 log files for 3 active log files at any given time...
  rm -f $(ls -1t /config/logs/$scriptName-* | tail -n +2)
  # delete log files older than 5 days
  find "/config/logs" -type f -iname "$scriptName-*.txt" -mtime +5 -delete
  
  if [ ! -f "/config/logs/$logFileName" ]; then
    echo "" > "/config/logs/$logFileName"
    chmod 666 "/config/logs/$logFileName"
  fi
}


getArrAppInfo () {
  if [ -z "$arrUrl" ] || [ -z "$arrApiKey" ]; then
    arrUrlBase="$(xq -x //Config/UrlBase < /config/config.xml)"
    arrName="$(xq -x //Config/InstanceName < /config/config.xml)"
    arrApiKey="$(xq -x //Config/ApiKey < /config/config.xml)"
    arrPort="$(xq -x //Config/Port < /config/config.xml)"
    if [ "$arrUrlBase" == "null" ] || [ -z "$arrUrlBase" ] || [ "$arrUrlBase" == "/" ]; then
      arrUrlBase=""
    else
      arrUrlBase=$(echo "$arrUrlBase" | sed -e 's/^\/*//' -e 's/\/*$//')
      arrUrlBase="/$arrUrlBase"
    fi
    arrUrl="http://127.0.0.1:${arrPort}${arrUrlBase}"
  fi
  arrUrl="${arrUrl%/}"
}

verifyApiAccess () {
  if ! command -v curl >/dev/null 2>&1 || ! command -v jq >/dev/null 2>&1; then
    log "Fatal: 'curl' or 'jq' is not installed."
    return 1
  fi
  until false
  do
    arrApiTest=""
    for arrApiVersion in "v3" "v1"; do
      echo "$arrUrl/api/$arrApiVersion/system/status?apikey=$arrApiKey"
      arrApiTest="$(curl -s "$arrUrl/api/$arrApiVersion/system/status?apikey=$arrApiKey" | jq -r '.instanceName // empty' 2>/dev/null)"
      if [ -n "$arrApiTest" ]; then
        break 2
      fi
    done
    log "$arrName is not ready, sleeping until valid response..."
    sleep 1
  done
  log "$arrName ($arrApiTest) is ready!"
}

ConfValidationCheck () {
  if [ ! -f "/config/extended.conf" ]; then
    log "ERROR :: \"extended.conf\" file is missing..."
    log "ERROR :: Download the extended.conf config file and place it into \"/config\" folder..."
    log "ERROR :: Exiting..."
    exit
  fi
  if [ -z "$enableAutoConfig" ]; then
    log "ERROR :: \"extended.conf\" file is unreadable..."
    log "ERROR :: Likely caused by editing with a non unix/linux compatible editor, to fix, replace the file with a valid one or correct the line endings..."
    log "ERROR :: Exiting..."
    exit
  fi
}

logfileSetup
ConfValidationCheck

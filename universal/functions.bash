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
  # Get Arr App information
  if [ -z "$arrUrl" ] || [ -z "$arrApiKey" ]; then
    arrUrlBase="$(sed -n 's:.*<UrlBase>\(.*\)</UrlBase>.*:\1:p' /config/config.xml | head -n1)"
    if [ -z "$arrUrlBase" ]; then
      arrUrlBase=""
    else
      arrUrlBase="/$(echo "$arrUrlBase" | sed 's:^/*::; s:/*$::')"
    fi
    arrName="$(sed -n 's:.*<InstanceName>\(.*\)</InstanceName>.*:\1:p' /config/config.xml | head -n1)"
    arrApiKey="$(sed -n 's:.*<ApiKey>\(.*\)</ApiKey>.*:\1:p' /config/config.xml | head -n1)"
    arrPort="$(sed -n 's:.*<Port>\(.*\)</Port>.*:\1:p' /config/config.xml | head -n1)"
    arrUrl="http://127.0.0.1:${arrPort}${arrUrlBase}"
  fi
}

verifyApiAccess () {
  until false
  do
    arrApiTest=""
    arrApiVersion=""

    arrApiVersion="v1"
    arrApiTest="$(curl -fsS "$arrUrl/api/$arrApiVersion/system/status?apikey=$arrApiKey" 2>/dev/null | jq -er '.instanceName // .appName // empty' 2>/dev/null || true)"

    if [ -z "$arrApiTest" ]; then
      arrApiVersion="v3"
      arrApiTest="$(curl -fsS "$arrUrl/api/$arrApiVersion/system/status?apikey=$arrApiKey" 2>/dev/null | jq -er '.instanceName // .appName // empty' 2>/dev/null || true)"
    fi

    if [ ! -z "$arrApiTest" ]; then
      break
    else
      log "$arrName is not ready, sleeping until valid response..."
      sleep 1
    fi
  done
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

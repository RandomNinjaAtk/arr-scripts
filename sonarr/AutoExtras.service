#!/usr/bin/env bash
scriptVersion="1.0.1"

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
  echo $m_time" :: AutoExtras :: $scriptVersion :: "$1
}

# auto-clean up log file to reduce space usage
if [ -f "/config/logs/AutoExtras.txt" ]; then
	find /config/logs -type f -name "AutoExtras.txt" -size +1024k -delete
fi

if [ ! -f "/config/logs/AutoExtras.txt" ]; then
    touch "/config/logs/AutoExtras.txt"
    chmod 666 "/config/logs/AutoExtras.txt"
fi
exec &> >(tee -a "/config/logs/AutoExtras.txt")

sonarrSeriesList=$(curl -s --header "X-Api-Key:"${arrApiKey} --request GET  "$arrUrl/api/v3/series")
sonarrSeriesTotal=$(echo "${sonarrSeriesList}"  | jq -r '.[].id' | wc -l)
sonarrSeriesIds=$(echo "${sonarrSeriesList}" | jq -r '.[].id')

loopCount=0
for id in $(echo $sonarrSeriesIds); do
    loopCount=$(( $loopCount + 1 ))
    arrSeriesData="$(echo "$sonarrSeriesList" | jq -r ".[] | select(.id==$id)")"
    arrSeriesPath="$(echo "$arrSeriesData" | jq -r ".path")"
    arrSeriesTitle="$(echo "$arrSeriesData" | jq -r ".title")"
    if [ -d "$arrSeriesPath" ]; then
      log "$loopCount of $sonarrSeriesTotal :: $id :: $arrSeriesTitle :: Processing with Extras.bash"
      bash /config/extended/scripts/Extras.bash "$id"
    else
      log "$loopCount of $sonarrSeriesTotal :: $id :: $arrSeriesTitle :: Series folder does not exist, skipping..."
      continue
    fi
done

exit

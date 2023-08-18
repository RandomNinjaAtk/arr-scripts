#!/usr/bin/with-contenv bash
scriptVersion="1.0"
scriptName="RA-ROM-Downloader"
romPath="$romPath/RA_collection"

#### Funcitons
logfileSetup () {
  # auto-clean up log file to reduce space usage
  if [ -f "/config/$scriptName.log" ]; then
    if find /config -type f -name "$scriptName.log" -size +1024k | read; then
      echo "" > /config/$scriptName.log
    fi
  fi
  
  if [ ! -f "/config/$scriptName.log" ]; then
    echo "" > /config/$scriptName.log
    chmod 666 "/config/$scriptName.log"
  fi
}


DownloadRomCountSummary () {
  OIFS="$IFS"
  IFS=$'\n'
  romCount=$(find "$romPath" -type f -iname "*.zip" | wc -l)
  platformCount=$(find "/$romPath" -maxdepth 1 -mindepth 1 -type d | wc -l)
  echo "################## ROM SUMMARY ##################"  2>&1 | tee -a /config/$scriptName.log
  echo "$romCount ROMS downloaded on $platformCount different platforms!!!"  2>&1 | tee -a /config/$scriptName.log
  echo "############### DETAILED SUMMARY ################"  2>&1 | tee -a /config/$scriptName.log
  echo "Platforms ($platformCount):;Total:" > /config/temp
  for romfolder in $(find "/$romPath" -maxdepth 1 -mindepth 1 -type d); do
    platform="$(basename "$romfolder")"
    platformRomCount=$(find "$romfolder" -type f  -iname "*.zip" | wc -l)
    echo "$platform;$platformRomCount" >> /config/temp
  done
  echo "Totals:;$romCount;" >> /config/temp
  data=$(cat /config/temp | column -s";" -t)
  rm /config/temp
  echo "$data"  2>&1 | tee -a /config/$scriptName.log
  IFS="$OIFS"
}

DownloadRoms () {
  echo "############### UPDATING ROMS #################" 2>&1 | tee -a /config/$scriptName.log
    rclone sync -P --http-url https://ia902505.us.archive.org ":http:/27/items/retroachievements_collection_v5" "$romPath" --filter="- SNES/**" --filter="- NES/**" --filter="- PlayStation Portable/**" --filter="- PlayStation/**" --filter="- PlayStation 2/**" --filter "- retroachievements_collection*" --filter "- TamperMonkeyRetroachievements*" --filter "- __ia_thumb.jpg" --filter "- rclone.txt" --local-case-sensitive --delete-before --transfers $downloadTransfers --checkers $downloadCheckers --tpslimit $downloadTpslimit --log-file="/config/rclong.log"
  rclone sync -P --http-url https://ia902701.us.archive.org ":http:/29/items/retroachievements_collection_NES/NES" "$romPath/NES" --local-case-sensitive --delete-before --transfers $downloadTransfers --checkers $downloadCheckers --tpslimit $downloadTpslimit --log-file="/config/rclong.log"
  rclone sync -P --http-url https://ia802606.us.archive.org ":http:/25/items/retroachievements_collection_SNES/SNES" "$romPath/SNES" --local-case-sensitive --delete-before --transfers $downloadTransfers --checkers $downloadCheckers --tpslimit $downloadTpslimit --filter="- *(MSU)*" --log-file="/config/rclong.log"
  rclone sync -P --http-url https://ia902607.us.archive.org ":http:/23/items/retroachievements_collection_PlayStation_Portable/PlayStation Portable" "$romPath/PlayStation Portable" --local-case-sensitive --delete-before --transfers $downloadTransfers --checkers $downloadCheckers --tpslimit $downloadTpslimit --log-file="/config/rclong.log"
  rclone sync -P --http-url https://ia902709.us.archive.org ":http:/31/items/retroachievements_collection_PlayStation/PlayStation" "$romPath/PlayStation" --local-case-sensitive --delete-before --transfers $downloadTransfers --checkers $downloadCheckers --tpslimit $downloadTpslimit --log-file="/config/rclong.log"
  rclone sync -P --http-url https://ia904707.us.archive.org ":http:/16/items/retroachievements_collection_PS2/PlayStation 2" "$romPath/PlayStation 2" --local-case-sensitive --delete-before --transfers $downloadTransfers --checkers $downloadCheckers --tpslimit $downloadTpslimit --log-file="/config/rclong.log"
}

# Loop Script
for (( ; ; )); do
  let i++
  logfileSetup
  echo "Script starting..." 2>&1 | tee -a /config/$scriptName.log
  DownloadRomCountSummary
  DownloadRoms
  DownloadRomCountSummary
  echo "Script sleeping for $downloadScriptInterval..." 2>&1 | tee -a /config/$scriptName.log
  DownloadRomCountSummary
  sleep $downloadScriptInterval
done
exit

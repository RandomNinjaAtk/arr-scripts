#!/usr/bin/env bash
# This script is for dev purposes
scriptVersion="1.0"
scriptName="RA-ROM-Downloader"

#### Import Settings
source /config/extended.conf


#### Funcitons
log () {
  m_time=`date "+%F %T"`
  echo $m_time" :: $scriptName :: $scriptVersion :: "$1 2>&1 | tee -a /config/$scriptName.log
}

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

UrlDecode () { : "${*//+/ }"; echo -e "${_//%/\\x}"; }

CreatePlatformRomList () {
  if [ -f /config/romlist ]; then
     rm /config/romlist
  fi
  archiveUrl="$(wget -qO- "$1" | grep -io '<a href=['"'"'"][^"'"'"']*['"'"'"]' |   sed -e 's/^<a href=["'"'"']//i' -e 's/["'"'"']$//i' | sed 's/\///g' | sort -u | sed "s|^|$1|")"
  echo "$archiveUrl" | grep -v "\.\." | sort >> /config/romlist
}

DownloadFileVerification () {
  log "$processNumber/$platformToProcessNumber :: $platform :: $romProcessNumber/$romListCount :: ${fileName} :: Verifing Download..."
  case "$1" in
    *.zip|*.ZIP)
      verify="$(unzip -t "$1" &>/dev/null; echo $?)"
      ;;
    *.rar|*.RAR)
      verify="$(unrar t "$1" &>/dev/null; echo $?)"
      ;;
    *.7z|*.7Z)
      verify="$(7z t "$1" &>/dev/null; echo $?)"
      ;;
    *.chd|*.CHD)
      verify="$(chdman verify -i "$1" &>/dev/null; echo $?)"
      ;;
    *.iso|*.ISO|*.hex|*.HEX|*.wasm|*.WASM|*.sv|*.SV)
      echo "No methdod to verify this type of file (iso,hex,wasm,sv)"
      verify="0"
      ;;
  esac
  
  if [ "$verify" != "0" ]; then
    log "$processNumber/$platformToProcessNumber :: $platform :: $romProcessNumber/$romListCount :: ${fileName} :: ERROR :: Failed Verification!"
    rm "$1"
  else
    log "$processNumber/$platformToProcessNumber :: $platform :: $romProcessNumber/$romListCount :: ${fileName} :: Download Verified!"
  fi
}

#### Platforms
PlatformSnes () {
  platformName="Super Nintentdo"
  platformArchiveContentsUrl="https://archive.org/download/retroachievements_collection_SNES/SNES/"
  platformFolder="snes"
  consoleRomFileExt=".smc, .fig, .sfc, .gd3, .gd7, .dx2, .bsx, .swc, .zip, .7z"
  raConsoleId="3"
  uncompressRom="false"
  compressRom="false"
}

PlatformMegadrive () {
  platformName="Mega Drive"
  platformArchiveContentsUrl="https://archive.org/download/retroachievements_collection_v5/Mega%20Drive/"
  platformFolder="megadrive"
  consoleRomFileExt=".bin, .gen, .md, .sg, .smd, .zip, .7z"
  raConsoleId="1"
  uncompressRom="false"
  compressRom="false"
}


platformsToProcessNumber=0
IFS=',' read -r -a filters <<< "$platforms"
for platform in "${filters[@]}"
do
  platformToProcessNumber=$(( $platformToProcessNumber + 1 ))
done

processNumber=0
IFS=',' read -r -a filters <<< "$platforms"
for platform in "${filters[@]}"
do
  processNumber=$(( $processNumber + 1 ))
  log "$processNumber/$platformToProcessNumber :: $platform"
  if [ $platform == "snes" ]; then
    PlatformSnes
  elif [ $platform == "megadrive" ]; then
    PlatformMegadrive
  else
    log "ERROR :: No Platforms Selected, exiting..."
    exit
  fi
  log "$processNumber/$platformToProcessNumber :: $platform :: Finding ROMS..."
  CreatePlatformRomList "$platformArchiveContentsUrl"
  outputdir="$romPath/$platformFolder"

  romlist=$(cat /config/romlist)
  romListCount=$(echo "$romlist" | wc -l)
  log "$processNumber/$platformToProcessNumber :: $platform :: $romListCount ROMS Found!"
  romProcessNumber=0
  echo "$romlist" | while read -r rom; do

    romProcessNumber=$(( $romProcessNumber + 1 ))
    archiveContentsUrl="$rom/"
    archiveUrl="$(wget -qO- "$archiveContentsUrl" | grep -i ".zip" |  grep -io '<a href=['"'"'"][^"'"'"']*['"'"'"]' |   sed -e 's/^<a href=["'"'"']//i' -e 's/["'"'"']$//i' | sed 's/\///g' | sort -u | sed "s|^|$archiveContentsUrl|")"
    echo "$archiveUrl" >> /config/romfilelist
    romfiles="$(cat /config/romfilelist | awk '{ print length, $0 }' | sort -n | cut -d" " -f2-)"

    # debugging
    #echo "original list: "
    #cat romfilelist
    #echo ""
    #echo "rom file list sorted by length: "
    #echo "$romfiles"
    #filteredUsaRoms="$(echo "$romfiles" | grep "%20%28U%29" | head -n 1)"
    #echo ""
    #echo "filtered:"
    #echo "$filteredUsaRoms"
    #if [ -f romfilelist ]; then
    #    rm romfilelist
    #fi
    #continue\

    filteredUsaRoms="$(echo "$romfiles" | grep -i "%20%28U%29" | head -n 1)"
    filteredUsaRomscount="$(echo "$romfiles" | grep -i "%20%28U%29" | head -n 1 | wc -l)"
    filteredUsa2Roms="$(echo "$romfiles" | grep -i "%20%28USA%29" | head -n 1)"
    filteredUsa2Romscount="$(echo "$romfiles" | grep -i "%20%28USA%29" | head -n 1 | wc -l)"
    filteredEuropRoms="$(echo "$romfiles" | grep -i "%20%28E%29" | head -n 1)"
    filteredEuropRomscount="$(echo "$romfiles" | grep -i "%20%28E%29" | head -n 1 | wc -l)"
    filteredWorldRoms="$(echo "$romfiles" | grep -i "%20%28W%29" | head -n 1)"
    filteredWorldRomscount="$(echo "$romfiles" | grep -i "%20%28W%29" | head -n 1 | wc -l)"
    filteredJapanRoms="$(echo "$romfiles" | grep -i "%20%28J%29" | head -n 1)"
    filteredJapanRomscount="$(echo "$romfiles" | grep -i "%20%28J%29" | head -n 1 | wc -l)"
    filteredOtherRoms="$(echo "$romfiles" | head -n 1)"
    filteredOtherRomscount="$(echo "$romfiles" | head -n 1 | wc -l)"
    filteredOtherRomsDecoded="$(UrlDecode "$filteredOtherRoms")"
    subFolder="$(dirname "$filteredOtherRomsDecoded")"
    subFolder="$(basename "$subFolder")"
    romUrl=""
    if echo "$subFolder" | grep "~" | read; then
        subFolder="/$(echo "$subFolder" | cut -d "~" -f 2)/"
    else
        subFolder="/"
    fi

    if [ ! -d "${outputdir}${subFolder}" ]; then
        log "$processNumber/$platformToProcessNumber :: $platform :: $romProcessNumber/$romListCount :: Creating \"${subFolder}\" folder... "
        mkdir -p "${outputdir}${subFolder}"
        chmod 777 "${outputdir}${subFolder}"
    fi

    log "$processNumber/$platformToProcessNumber :: $platform :: $romProcessNumber/$romListCount :: Searching Archive URL ROM Folder"

    if [ $filteredUsaRomscount -eq 1 ]; then
        log "$processNumber/$platformToProcessNumber :: $platform :: $romProcessNumber/$romListCount :: USA (U) ROM FOUND"
        fileName="$(basename "$filteredUsaRoms")"
        fileName="$(UrlDecode "$fileName")"
        romUrl="$filteredUsaRoms"
    elif [ $filteredUsa2Romscount -eq 1 ]; then
        log "$processNumber/$platformToProcessNumber :: $platform :: $romProcessNumber/$romListCount :: USA (USA) ROM FOUND"
        fileName="$(basename "$filteredUsa2Roms")"
        fileName="$(UrlDecode "$fileName")"
        romUrl="$filteredUsa2Roms"
    elif [ $filteredEuropRomscount -eq 1 ]; then
        log "$processNumber/$platformToProcessNumber :: $platform :: $romProcessNumber/$romListCount :: EUROPE ROM FOUND"
        fileName="$(basename "$filteredEuropRoms")"
        fileName="$(UrlDecode "$fileName")"
        romUrl="$filteredEuropRoms"        
    elif [ $filteredWorldRomscount -eq 1 ]; then
        log "$processNumber/$platformToProcessNumber :: $platform :: $romProcessNumber/$romListCount :: WORLD ROM FOUND"
        fileName="$(basename "$filteredWorldRoms")"
        fileName="$(UrlDecode "$fileName")"
        romUrl="$filteredWorldRoms"        
    elif [ $filteredJapanRomscount -eq 1 ]; then
        log "$processNumber/$platformToProcessNumber :: $platform :: $romProcessNumber/$romListCount :: JAPAN ROM FOUND"
        fileName="$(basename "$filteredJapanRoms")"
        fileName="$(UrlDecode "$fileName")"
        romUrl="$filteredJapanRoms"        
    elif [ $filteredOtherRomscount -eq 1 ]; then
        log "$processNumber/$platformToProcessNumber :: $platform :: $romProcessNumber/$romListCount :: OTHER ROM FOUND"
        fileName="$(basename "$filteredOtherRoms")"
        fileName="$(UrlDecode "$fileName")"
        romUrl="$filteredOtherRoms"
    else
        log "$processNumber/$platformToProcessNumber :: $platform :: $romProcessNumber/$romListCount :: ERROR :: No Filtered Roms Found..."
        continue
    fi

    if [ ! -f "${outputdir}${subFolder}${fileName}" ]; then
        log "$processNumber/$platformToProcessNumber :: $platform :: $romProcessNumber/$romListCount :: ${fileName} :: ROM downloading to \"${outputdir}${subFolder}\"..."
        wget "$romUrl" -O "${outputdir}${subFolder}${fileName}"
    else
        log "$processNumber/$platformToProcessNumber :: $platform :: $romProcessNumber/$romListCount :: ${fileName} :: ROM previously downloaded..." 
    fi

    if [ -f "${outputdir}${subFolder}${fileName}" ]; then
        DownloadFileVerification "${outputdir}${subFolder}${fileName}"
        log "$processNumber/$platformToProcessNumber :: $platform :: $romProcessNumber/$romListCount :: ${fileName} ::  Setting Permissions to 666"
        chmod 666 "${outputdir}${subFolder}${fileName}"
    fi

    if [ -f /config/romfilelist ]; then
        rm /config/romfilelist
    fi
  done
  downloadedRomCount=$(find "$outputdir" -type f | wc -l)
  log "$processNumber/$platformToProcessNumber :: $platform :: $downloadedRomCount ROMS Successfully Downloaded!!"
done

exit

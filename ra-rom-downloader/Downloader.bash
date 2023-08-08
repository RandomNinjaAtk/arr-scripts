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

DownloadFile () {
  # $1 = URL
  # $2 = Output Folder/file
  # $3 = Number of concurrent connections to use
  axel -n $3 --output="$2" "$1" | awk -W interactive '$0~/\[/{printf "%s'$'\r''", $0}'
  #wget -q --show-progress --progress=bar:force 2>&1 "$1" -O "$2"
  if [ ! -f "$2" ]; then
    log "$processNumber/$platformToProcessNumber :: $platformName :: $romProcessNumber/$romListCount :: ${fileName} :: Download Failed"
  fi
}

DownloadFileVerification () {
  log "$processNumber/$platformToProcessNumber :: $platformName :: $romProcessNumber/$romListCount :: ${fileName} :: Verifing Download..."
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
    log "$processNumber/$platformToProcessNumber :: $platformName :: $romProcessNumber/$romListCount :: ${fileName} :: ERROR :: Failed Verification!"
    rm "$1"
  else
    log "$processNumber/$platformToProcessNumber :: $platformName :: $romProcessNumber/$romListCount :: ${fileName} :: Download Verified!"
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

PlatformN64 () {
  platformName="Nintendo 64"
  platformArchiveContentsUrl="https://archive.org/download/retroachievements_collection_v5/Nintendo%2064/"
  platformFolder="n64"
  consoleRomFileExt=".z64, .n64, .v64, .zip, .7z"
  raConsoleId="2"
  uncompressRom="false"
  compressRom="false"
}

PlatformMegaduck () {
  platformName="Mega Duck"
  platformArchiveContentsUrl="https://archive.org/download/retroachievements_collection_v5/Mega%20Duck/"
  platformFolder="megaduck"
  consoleRomFileExt=".bin, .zip, .7z"
  raConsoleId="69"
  uncompressRom="false"
  compressRom="false"
}

PlatformPokemini () {
  platformName="Pokemon Mini"
  platformArchiveContentsUrl="https://archive.org/download/retroachievements_collection_v5/Pokemon%20Mini/"
  platformFolder="pokemini"
  consoleRomFileExt=".min, .zip, .7z"
  raConsoleId="24"
  uncompressRom="false"
  compressRom="false"
}

PlatformVirtualboy () {
  platformName="Virtual Boy"
  platformArchiveContentsUrl="https://archive.org/download/retroachievements_collection_v5/Virtual%20Boy/"
  platformFolder="virtualboy"
  consoleRomFileExt=".vb, .zip, .7z"
  raConsoleId="28"
  uncompressRom="false"
  compressRom="false"
}

PlatformNes () {
  platformName="Nintendo Entertainment System"
  platformArchiveContentsUrl="https://archive.org/download/retroachievements_collection_NES/NES/"
  platformFolder="nes"
  consoleRomFileExt=".nes, .unif, .unf, .zip, .7z"
  raConsoleId="7"
  uncompressRom="false"
  compressRom="false"
}

Platform3do () {
  platformName="3DO Interactive Multiplayer"
  platformArchiveContentsUrl="https://archive.org/download/retroachievements_collection_v5/3DO%20Interactive%20Multiplayer/"
  platformFolder="3do"
  consoleRomFileExt=".iso, .chd, .cue"
  raConsoleId="43"
  uncompressRom="false"
  compressRom="false"
}

PlatformArduboy () {
  platformName="Arduboy"
  platformArchiveContentsUrl="https://archive.org/download/retroachievements_collection_v5/Arduboy/"
  platformFolder="arduboy"
  consoleRomFileExt=".hex, .zip, .7z"
  raConsoleId="71"
  uncompressRom="false"
  compressRom="false"
}

PlatformSega32x () {
  platformName="Sega 32X"
  platformArchiveContentsUrl="https://archive.org/download/retroachievements_collection_v5/32X/"
  platformFolder="sega32x"
  consoleRomFileExt=".32x, .smd, .bin, .md, .zip, .7z"
  raConsoleId="10"
  uncompressRom="false"
  compressRom="false"
}

PlatformMastersystem () {
  platformName="Sega Master System"
  platformArchiveContentsUrl="https://archive.org/download/retroachievements_collection_v5/Master%20System/"
  platformFolder="mastersystem"
  consoleRomFileExt=".bin, .sms, .zip, .7z"
  raConsoleId="11"
  uncompressRom="false"
  compressRom="false"
}

PlatformSg1000 () {
  platformName="SG-1000"
  platformArchiveContentsUrl="https://archive.org/download/retroachievements_collection_v5/SG-1000/"
  platformFolder="sg1000"
  consoleRomFileExt=".bin, .sg, .zip, .7z"
  raConsoleId="33"
  uncompressRom="false"
  compressRom="false"
}

PlatformAtarilynx () {
  platformName="Atari Lynx"
  platformArchiveContentsUrl="https://archive.org/download/retroachievements_collection_v5/Atari%20Lynx/"
  platformFolder="atarilynx"
  consoleRomFileExt=".lnx, .zip, .7z"
  raConsoleId="13"
  uncompressRom="false"
  compressRom="false"
}

PlatformJaguar () {
  platformName="Atari Jaguar"
  platformArchiveContentsUrl="https://archive.org/download/retroachievements_collection_v5/Atari%20Jaguar/"
  platformFolder="jaguar"
  consoleRomFileExt=".cue, .j64, .jag, .cof, .abs, .cdi, .rom, .zip, .7z"
  raConsoleId="17"
  uncompressRom="false"
  compressRom="false"
}

PlatformGameBoy () {
  platformName="Game Boy"
  platformArchiveContentsUrl="https://archive.org/download/retroachievements_collection_v5/Game%20Boy/"
  platformFolder="gb"
  consoleRomFileExt=".gb, .zip, .7z"
  raConsoleId="4"
  uncompressRom="false"
  compressRom="false"
}

PlatformGameBoyColor () {
  platformName="Game Boy Color"
  platformArchiveContentsUrl="https://archive.org/download/retroachievements_collection_v5/Game%20Boy%20Color/"
  platformFolder="gbc"
  consoleRomFileExt=".gbc, .zip, .7z"
  raConsoleId="6"
  uncompressRom="false"
  compressRom="false"
}

PlatformGameBoyAdvance () {
  platformName="Game Boy Advance"
  platformArchiveContentsUrl="https://archive.org/download/retroachievements_collection_v5/Game%20Boy%20Advance/"
  platformFolder="gba"
  consoleRomFileExt=".gba, .zip, .7z"
  raConsoleId="5"
  uncompressRom="false"
  compressRom="false"
}

PlatformGameGear () {
  platformName="Game Gear"
  platformArchiveContentsUrl="https://archive.org/download/retroachievements_collection_v5/Game%20Gear/"
  platformFolder="gamegear"
  consoleRomFileExt=".bin, .gg, .zip, .7z"
  raConsoleId="15"
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
  if [ $platform == "snes" ]; then
    PlatformSnes
  elif [ $platform == "megadrive" ]; then
    PlatformMegadrive
  elif [ $platform == "n64" ]; then
    PlatformN64
  elif [ $platform == "megaduck" ]; then
    PlatformMegaduck
  elif [ $platform == "pokemini" ]; then
    PlatformPokemini
  elif [ $platform == "virtualboy" ]; then
    PlatformVirtualboy
  elif [ $platform == "nes" ]; then
    PlatformNes
  elif [ $platform == "arduboy" ]; then
    PlatformArduboy
  elif [ $platform == "sega32x" ]; then
    PlatformSega32x
  elif [ $platform == "mastersystem" ]; then
    PlatformMastersystem
  elif [ $platform == "sg1000" ]; then
    PlatformSg1000
  elif [ $platform == "atarilynx" ]; then
    PlatformAtarilynx
  elif [ $platform == "jaguar" ]; then
    PlatformJaguar
  elif [ $platform == "gb" ]; then
    PlatformGameBoy
  elif [ $platform == "gbc" ]; then
    PlatformGameBoyColor
  elif [ $platform == "gba" ]; then
    PlatformGameBoyAdvance
  elif [ $platform == "gamegear" ]; then
    PlatformGameGear
  else
    log "ERROR :: No Platforms Selected, exiting..."
    exit
  fi

  log "$processNumber/$platformToProcessNumber :: $platformName :: Starting..."
  log "$processNumber/$platformToProcessNumber :: $platformName :: Finding ROMS..."
  CreatePlatformRomList "$platformArchiveContentsUrl"
  outputdir="$romPath/$platformFolder"

  romlist=$(cat /config/romlist)
  romListCount=$(echo "$romlist" | wc -l)
  log "$processNumber/$platformToProcessNumber :: $platformName :: $romListCount ROMS Found!"
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
    filteredUsa3Roms="$(echo "$romfiles" | grep -i "%20%28UE%29" | head -n 1)"
    filteredUsa3Romscount="$(echo "$romfiles" | grep -i "%20%28UE%29" | head -n 1 | wc -l)"
    filteredEuropeRoms="$(echo "$romfiles" | grep -i "%20%28E%29" | head -n 1)"
    filteredEuropeRomscount="$(echo "$romfiles" | grep -i "%20%28E%29" | head -n 1 | wc -l)"
    filteredEurope2Roms="$(echo "$romfiles" | grep -i "%20%28E%29" | head -n 1)"
    filteredEurope2Romscount="$(echo "$romfiles" | grep -i "%20%28Europe%29" | head -n 1 | wc -l)"
    filteredWorldRoms="$(echo "$romfiles" | grep -i "%20%28W%29" | head -n 1)"
    filteredWorldRomscount="$(echo "$romfiles" | grep -i "%20%28W%29" | head -n 1 | wc -l)"
    filteredWorld2Roms="$(echo "$romfiles" | grep -i "%20%28World%29" | head -n 1)"
    filteredWorld2Romscount="$(echo "$romfiles" | grep -i "%20%28World%29" | head -n 1 | wc -l)"
    filteredJapanRoms="$(echo "$romfiles" | grep -i "%20%28J%29" | head -n 1)"
    filteredJapanRomscount="$(echo "$romfiles" | grep -i "%20%28J%29" | head -n 1 | wc -l)"
    filteredJapan2Roms="$(echo "$romfiles" | grep -i "%20%28Japan%29" | head -n 1)"
    filteredJapan2Romscount="$(echo "$romfiles" | grep -i "%20%28Japan%29" | head -n 1 | wc -l)"
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
        log "$processNumber/$platformToProcessNumber :: $platformName :: $romProcessNumber/$romListCount :: Creating \"${subFolder}\" folder... "
        mkdir -p "${outputdir}${subFolder}"
        chmod 777 "${outputdir}${subFolder}"
    fi

    log "$processNumber/$platformToProcessNumber :: $platformName :: $romProcessNumber/$romListCount :: Searching Archive URL ROM Folder"

    if [ $filteredUsaRomscount -eq 1 ]; then
        log "$processNumber/$platformToProcessNumber :: $platformName :: $romProcessNumber/$romListCount :: USA (U) ROM FOUND"
        fileName="$(basename "$filteredUsaRoms")"
        fileName="$(UrlDecode "$fileName")"
        romUrl="$filteredUsaRoms"
    elif [ $filteredUsa2Romscount -eq 1 ]; then
        log "$processNumber/$platformToProcessNumber :: $platformName :: $romProcessNumber/$romListCount :: USA (USA) ROM FOUND"
        fileName="$(basename "$filteredUsa2Roms")"
        fileName="$(UrlDecode "$fileName")"
        romUrl="$filteredUsa2Roms"
    elif [ $filteredUsa3Romscount -eq 1 ]; then
        log "$processNumber/$platformToProcessNumber :: $platformName :: $romProcessNumber/$romListCount :: USA (USA) ROM FOUND"
        fileName="$(basename "$filteredUsa3Roms")"
        fileName="$(UrlDecode "$fileName")"
        romUrl="$filteredUsa3Roms"
    elif [ $filteredEuropeRomscount -eq 1 ]; then
        log "$processNumber/$platformToProcessNumber :: $platformName :: $romProcessNumber/$romListCount :: EUROPE ROM FOUND"
        fileName="$(basename "$filteredEuropeRoms")"
        fileName="$(UrlDecode "$fileName")"
        romUrl="$filteredEuropeRoms"
    elif [ $filteredEurope2Romscount -eq 1 ]; then
        log "$processNumber/$platformToProcessNumber :: $platformName :: $romProcessNumber/$romListCount :: EUROPE ROM FOUND"
        fileName="$(basename "$filteredEurope2Roms")"
        fileName="$(UrlDecode "$fileName")"
        romUrl="$filteredEurope2Roms"
    elif [ $filteredWorldRomscount -eq 1 ]; then
        log "$processNumber/$platformToProcessNumber :: $platformName :: $romProcessNumber/$romListCount :: WORLD ROM FOUND"
        fileName="$(basename "$filteredWorldRoms")"
        fileName="$(UrlDecode "$fileName")"
        romUrl="$filteredWorldRoms"
    elif [ $filteredWorld2Romscount -eq 1 ]; then
        log "$processNumber/$platformToProcessNumber :: $platformName :: $romProcessNumber/$romListCount :: WORLD ROM FOUND"
        fileName="$(basename "$filteredWorld2Roms")"
        fileName="$(UrlDecode "$fileName")"
        romUrl="$filteredWorld2Roms"
    elif [ $filteredJapanRomscount -eq 1 ]; then
        log "$processNumber/$platformToProcessNumber :: $platformName :: $romProcessNumber/$romListCount :: JAPAN ROM FOUND"
        fileName="$(basename "$filteredJapanRoms")"
        fileName="$(UrlDecode "$fileName")"
        romUrl="$filteredJapanRoms"
    elif [ $filteredJapan2Romscount -eq 1 ]; then
        log "$processNumber/$platformToProcessNumber :: $platformName :: $romProcessNumber/$romListCount :: JAPAN ROM FOUND"
        fileName="$(basename "$filteredJapan2Roms")"
        fileName="$(UrlDecode "$fileName")"
        romUrl="$filteredJapan2Roms"       
    elif [ $filteredOtherRomscount -eq 1 ]; then
        log "$processNumber/$platformToProcessNumber :: $platformName :: $romProcessNumber/$romListCount :: OTHER ROM FOUND"
        fileName="$(basename "$filteredOtherRoms")"
        fileName="$(UrlDecode "$fileName")"
        romUrl="$filteredOtherRoms"
    else
        log "$processNumber/$platformToProcessNumber :: $platformName :: $romProcessNumber/$romListCount :: ERROR :: No Filtered Roms Found..."
        continue
    fi

    # download file
    if [ ! -f "${outputdir}${subFolder}${fileName}" ]; then
        log "$processNumber/$platformToProcessNumber :: $platformName :: $romProcessNumber/$romListCount :: ${fileName} :: ROM downloading to \"${outputdir}${subFolder}\"..."
        #wget "$romUrl" -O "${outputdir}${subFolder}${fileName}"
        DownloadFile "$romUrl" "${outputdir}${subFolder}${fileName}" "$concurrentConnectionCount"
    else
        log "$processNumber/$platformToProcessNumber :: $platformName :: $romProcessNumber/$romListCount :: ${fileName} :: ROM previously downloaded..." 
    fi

    # verify download
    if [ -f "${outputdir}${subFolder}${fileName}" ]; then
        DownloadFileVerification "${outputdir}${subFolder}${fileName}"
    fi

    # set permisions
    if [ -f "${outputdir}${subFolder}${fileName}" ]; then
        log "$processNumber/$platformToProcessNumber :: $platformName :: $romProcessNumber/$romListCount :: ${fileName} ::  Setting Permissions to 666"
        chmod 666 "${outputdir}${subFolder}${fileName}"
    fi

    if [ -f /config/romfilelist ]; then
        rm /config/romfilelist
    fi
  done
  downloadedRomCount=$(find "$outputdir" -type f | wc -l)
  log "$processNumber/$platformToProcessNumber :: $platformName :: $downloadedRomCount ROMS Successfully Downloaded!!"
done

exit

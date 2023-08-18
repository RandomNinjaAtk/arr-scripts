#!/usr/bin/env bash
# This script is for dev purposes
scriptVersion="1.1"
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
  sed -i '/#maincontent/d' /config/romlist
  sed -i '/blog.archive.org/d' /config/romlist
}

DownloadFile () {
  # $1 = URL
  # $2 = Output Folder/file
  # $3 = Number of concurrent connections to use
  axel -n $3 --output="$2" "$1" | awk -W interactive '$0~/\[/{printf "%s'$'\r''", $0}'
  #wget -q --show-progress --progress=bar:force 2>&1 "$1" -O "$2"
  if [ ! -f "$2" ]; then
    log "$processNumber/$platformToProcessNumber :: $platformName :: $romProcessNumber/$romListCount :: ${fileName} :: Download Failed ($1)"
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

PlatformSelection () {
  if [ "$platform" == "snes" ]; then
    PlatformSnes
  elif [ "$platform" == "apple2" ]; then
    PlatformApple2
  elif [ "$platform" == "megadrive" ]; then
    PlatformMegadrive
  elif [ "$platform" == "n64" ]; then
    PlatformN64
  elif [ "$platform" == "megaduck" ]; then
    PlatformMegaduck
  elif [ "$platform" == "pokemini" ]; then
    PlatformPokemini
  elif [ "$platform" == "virtualboy" ]; then
    PlatformVirtualboy
  elif [ "$platform" == "nes" ]; then
    PlatformNes
  elif [ "$platform" == "arduboy" ]; then
    PlatformArduboy
  elif [ "$platform" == "sega32x" ]; then
    PlatformSega32x
  elif [ "$platform" == "mastersystem" ]; then
    PlatformMastersystem
  elif [ "$platform" == "sg1000" ]; then
    PlatformSg1000
  elif [ "$platform" == "atarilynx" ]; then
    PlatformAtarilynx
  elif [ "$platform" == "jaguar" ]; then
    PlatformJaguar
  elif [ "$platform" == "gb" ]; then
    PlatformGameBoy
  elif [ "$platform" == "gbc" ]; then
    PlatformGameBoyColor
  elif [ "$platform" == "gba" ]; then
    PlatformGameBoyAdvance
  elif [ "$platform" == "gamegear" ]; then
    PlatformGameGear
  elif [ "$platform" == "atari2600" ]; then
    PlatformAtari2600
  elif [ "$platform" == "atari7800" ]; then
    PlatformAtari7800
  elif [ "$platform" == "nds" ]; then
    PlatformNintendoDS
  elif [ "$platform" == "colecovision" ]; then
    PlatformColecoVision
  elif [ "$platform" == "intellivision" ]; then
    PlatformIntellivision
  elif [ "$platform" == "ngp" ]; then
    PlatformNeoGeoPocket
  elif [ "$platform" == "ndsi" ]; then
    PlatformNintendoDSi
  elif [ "$platform" == "wasm4" ]; then
    PlatformNintendoWASM-4
  elif [ "$platform" == "channelf" ]; then
    PlatformNintendoChannelF
  elif [ "$platform" == "o2em" ]; then
    PlatformO2em
  elif [ "$platform" == "arcadia" ]; then
    PlatformArcadia
  elif [ "$platform" == "supervision" ]; then
    PlatformSupervision
  elif [ "$platform" == "wswan" ]; then
    PlatformWonderSwan
  elif [ "$platform" == "vectrex" ]; then
    PlatformVectrex
  elif [ "$platform" == "amstradcpc" ]; then
    PlatformAmstradCPC
  elif [ "$platform" == "psp" ]; then
    PlatformPsp
  else
    log "ERROR :: No Platforms Selected, exiting..."
    exit
  fi
}

UncompressFile () {
  # $1 is input file
  # $2 is output folder
  log "$processNumber/$platformToProcessNumber :: $platformName :: $romProcessNumber/$romListCount :: ${fileName} :: Uncompressing \"$1\" to \"$2\""
  case "$1" in
    *.zip|*.ZIP)
      log "$processNumber/$platformToProcessNumber :: $platformName :: $romProcessNumber/$romListCount :: ${fileName} :: Zip file detected!"
      unzip -o -d "$2" "$1" >/dev/null
      ;;
    *.rar|*.RAR)
      log "$processNumber/$platformToProcessNumber :: $platformName :: $romProcessNumber/$romListCount :: ${fileName} :: Rar file detected!"
      unrar x "$1" "$2" &>/dev/null
      ;;
    *.7z|*.7Z)
      log "$processNumber/$platformToProcessNumber :: $platformName :: $romProcessNumber/$romListCount :: ${fileName} :: 7z file detected!"
      7z e "$1" -o"$2" &>/dev/null
      ;;
  esac
  log "$processNumber/$platformToProcessNumber :: $platformName :: $romProcessNumber/$romListCount :: ${fileName} :: Uncompressing Complete!"
  rm "$1"
}

DownloadRomCountSummary () {
  log "Summarizing ROM counts..."
  romCount=$(find "$romPath" -type f | wc -l)
  platformCount=$(find "/$romPath" -maxdepth 1 -mindepth 1 -type d | wc -l)
  log "$romCount ROMS downloaded on $platformCount different platforms!!!"
  log "Platform breakdown...."
  echo "Platforms ($platformCount):;Total:;Released:;Hack/Homebrew/Proto/Unlicensed:" > /config/temp
  for romfolder in $(find "/$romPath" -maxdepth 1 -mindepth 1 -type d); do
    platform="$(basename "$romfolder")"
    PlatformSelection
    platformRomCount=$(find "$romPath/$platformFolder" -type f | wc -l)
    platformRomSubCount=$(find "$romPath/$platformFolder" -mindepth 2 -type f | wc -l)
    platformMainRomCount=$(( $platformRomCount - $platformRomSubCount ))
    echo "$platformName;$platformRomCount;$platformMainRomCount;$platformRomSubCount" >> /config/temp
  done
  platformRomSubCount=$(find "$romPath" -mindepth 3 -type f | wc -l)
  platformMainRomCount=$(( $romCount - $platformRomSubCount ))
  echo "Totals:;$romCount;$platformMainRomCount;$platformRomSubCount" >> /config/temp
  data=$(cat /config/temp | column -s";" -t)
  rm /config/temp
  echo "$data"
}

#### Platforms
PlatformPsp () {
  platformName="PlayStation Portable"
  platformArchiveContentsUrl="https://archive.org/download/retroachievements_collection_PlayStation_Portable/PlayStation%20Portable/"
  platformFolder="psp"
  consoleRomFileExt=".iso, .cso, .pbp"
  raConsoleId="41"
  uncompressRom="true"
  compressRom="false"
}

PlatformAmstradCPC () {
  platformName="Amstrad CPC"
  platformArchiveContentsUrl="https://archive.org/download/retroachievements_collection_v5/Amstrad%20CPC/"
  platformFolder="amstradcpc"
  consoleRomFileExt=".dsk, .sna, .tap, .cdt, .voc, .m3u, .zip, .7z"
  raConsoleId="37"
  uncompressRom="false"
  compressRom="false"
}

PlatformVectrex () {
  platformName="Vectrex"
  platformArchiveContentsUrl="https://archive.org/download/retroachievements_collection_v5/Vectrex/"
  platformFolder="vectrex"
  consoleRomFileExt=".bin, .gam, .vec, .zip, .7z"
  raConsoleId="46"
  uncompressRom="false"
  compressRom="false"
}

PlatformSupervision () {
  platformName="Watara Supervision"
  platformArchiveContentsUrl="https://archive.org/download/retroachievements_collection_v5/Watara%20Supervision/"
  platformFolder="supervision"
  consoleRomFileExt=".sv, .zip, .7z"
  raConsoleId="63"
  uncompressRom="false"
  compressRom="false"
}

PlatformWonderSwan () {
  platformName="WonderSwan"
  platformArchiveContentsUrl="https://archive.org/download/retroachievements_collection_v5/WonderSwan/"
  platformFolder="wswan"
  consoleRomFileExt=".ws, .zip, .7z"
  raConsoleId="53"
  uncompressRom="false"
  compressRom="false"
}

PlatformApple2 () {
  platformName="Apple II"
  platformArchiveContentsUrl="https://archive.org/download/retroachievements_collection_v5/Apple%20II/"
  platformFolder="apple2"
  consoleRomFileExt=".nib, .do, .po, .dsk, .mfi, .dfi, .rti, .edd, .woz, .wav, .zip, .7z"
  raConsoleId="38"
  uncompressRom="false"
  compressRom="false"
}

PlatformArcadia () {
  platformName="Arcadia 2001"
  platformArchiveContentsUrl="https://archive.org/download/retroachievements_collection_v5/Arcadia%202001/"
  platformFolder="arcadia"
  consoleRomFileExt=".bin, .zip, .7z"
  raConsoleId="73"
  uncompressRom="false"
  compressRom="false"
}

PlatformO2em () {
  platformName="Magnavox Odyssey 2"
  platformArchiveContentsUrl="https://archive.org/download/retroachievements_collection_v5/Magnavox%20Odyssey%202/"
  platformFolder="o2em"
  consoleRomFileExt=".bin, .zip, .7z"
  raConsoleId="23"
  uncompressRom="false"
  compressRom="false"
}

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

PlatformAtari2600 () {
  platformName="Atari 2600"
  platformArchiveContentsUrl="https://archive.org/download/retroachievements_collection_v5/Atari%202600/"
  platformFolder="atari2600"
  consoleRomFileExt=".a26, .bin, .zip, .7z"
  raConsoleId="25"
  uncompressRom="false"
  compressRom="false"
}

PlatformAtari7800 () {
  platformName="Atari 7800"
  platformArchiveContentsUrl="https://archive.org/download/retroachievements_collection_v5/Atari%207800/"
  platformFolder="atari7800"
  consoleRomFileExt=".a78, .bin, .zip, .7z"
  raConsoleId="51"
  uncompressRom="false"
  compressRom="false"
}

PlatformNintendoDS () {
  platformName="Nintendo DS"
  platformArchiveContentsUrl="https://archive.org/download/retroachievements_collection_v5/Nintendo%20DS/"
  downloadExtension="zip"
  platformFolder="nds"
  consoleRomFileExt=".nds, .bin, .zip, .7z"
  raConsoleId="18"
  uncompressRom="false"
  compressRom="false"
}

PlatformNintendoDSi () {
  platformName="Nintendo DSi"
  platformArchiveContentsUrl="https://archive.org/download/retroachievements_collection_v5/Nintendo%20DSi/"
  downloadExtension="zip"
  platformFolder="ndsi"
  consoleRomFileExt=".nds, .bin, .zip, .7z"
  raConsoleId="78"
  uncompressRom="false"
  compressRom="false"
}

PlatformColecoVision () {
  platformName="ColecoVision"
  platformArchiveContentsUrl="https://archive.org/download/retroachievements_collection_v5/ColecoVision/"
  downloadExtension="zip"
  platformFolder="colecovision"
  consoleRomFileExt=".bin, .col, .rom, .zip, .7z"
  raConsoleId="44"
  uncompressRom="false"
  compressRom="false"
}

PlatformIntellivision () {
  platformName="Intellivision"
  platformArchiveContentsUrl="https://archive.org/download/retroachievements_collection_v5/Intellivision/"
  downloadExtension="zip"
  platformFolder="intellivision"
  consoleRomFileExt=".int, .bin, .rom, .zip, .7z"
  raConsoleId="45"
  uncompressRom="false"
  compressRom="false"
}

PlatformNeoGeoPocket () {
  platformName="Neo Geo Pocket"
  platformArchiveContentsUrl="https://archive.org/download/retroachievements_collection_v5/Neo%20Geo%20Pocket/"
  downloadExtension="zip"
  platformFolder="ngp"
  consoleRomFileExt=".ngp, .zip, .7z"
  raConsoleId="14"
  uncompressRom="false"
  compressRom="false"
}

PlatformNintendoWASM-4 () {
  platformName="WASM-4"
  platformArchiveContentsUrl="https://archive.org/download/retroachievements_collection_v5/WASM-4/"
  downloadExtension="zip"
  platformFolder="wasm4"
  consoleRomFileExt=".wasm"
  raConsoleId="72"
  uncompressRom="false"
  compressRom="false"
}

PlatformNintendoChannelF () {
  platformName="Fairchild Channel F"
  platformArchiveContentsUrl="https://archive.org/download/retroachievements_collection_v5/Fairchild%20Channel%20F/"
  downloadExtension="zip"
  platformFolder="channelf"
  consoleRomFileExt=".zip, .rom, .bin, .chf"
  raConsoleId="57"
  uncompressRom="false"
  compressRom="false"
}

DownloadRomCountSummary
log "######################################"
log "Processing platforms..."
platform=""
platformsToProcessNumber=0
IFS=',' read -r -a filters <<< "$platforms"
for platform in "${filters[@]}"
do
  platformToProcessNumber=$(( $platformToProcessNumber + 1 ))
done

platform=""
processNumber=0
IFS=',' read -r -a filters <<< "$platforms"
for platform in "${filters[@]}"
do
  processNumber=$(( $processNumber + 1 ))
  PlatformSelection
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
    #echo "$rom"
    archiveUrl="$(wget -qO- "$archiveContentsUrl" | grep -i ".zip" |  grep -io '<a href=['"'"'"][^"'"'"']*['"'"'"]' |   sed -e 's/^<a href=["'"'"']//i' -e 's/["'"'"']$//i' | sed 's/\///g' | sort -u | sed "s|^|$archiveContentsUrl|")"
    echo "$archiveUrl" > /config/romfilelist
    romfiles="$(cat /config/romfilelist | awk '{ print length, $0 }' | sort -n | cut -d" " -f2-)"
    #echo $romfiles
    
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
    filteredEurope2Roms="$(echo "$romfiles" | grep -i "%20%28Europe%29" | head -n 1)"
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
        fileName="$(basename "$filteredUsaRoms")"
        fileName="$(UrlDecode "$fileName")"
        romUrl="$filteredUsaRoms"
        log "$processNumber/$platformToProcessNumber :: $platformName :: $romProcessNumber/$romListCount :: USA (U) ROM FOUND ($fileName)"
    elif [ $filteredUsa2Romscount -eq 1 ]; then
        fileName="$(basename "$filteredUsa2Roms")"
        fileName="$(UrlDecode "$fileName")"
        romUrl="$filteredUsa2Roms"
        log "$processNumber/$platformToProcessNumber :: $platformName :: $romProcessNumber/$romListCount :: USA (USA) ROM FOUND ($fileName)"
    elif [ $filteredUsa3Romscount -eq 1 ]; then
        fileName="$(basename "$filteredUsa3Roms")"
        fileName="$(UrlDecode "$fileName")"
        romUrl="$filteredUsa3Roms"
        log "$processNumber/$platformToProcessNumber :: $platformName :: $romProcessNumber/$romListCount :: USA (USA) ROM FOUND ($fileName)"
    elif [ $filteredEuropeRomscount -eq 1 ]; then
        fileName="$(basename "$filteredEuropeRoms")"
        fileName="$(UrlDecode "$fileName")"
        romUrl="$filteredEuropeRoms"
        log "$processNumber/$platformToProcessNumber :: $platformName :: $romProcessNumber/$romListCount :: EUROPE ROM FOUND ($fileName)"
    elif [ $filteredEurope2Romscount -eq 1 ]; then
        fileName="$(basename "$filteredEurope2Roms")"
        fileName="$(UrlDecode "$fileName")"
        romUrl="$filteredEurope2Roms"
        log "$processNumber/$platformToProcessNumber :: $platformName :: $romProcessNumber/$romListCount :: EUROPE ROM FOUND ($fileName)"
    elif [ $filteredWorldRomscount -eq 1 ]; then
        fileName="$(basename "$filteredWorldRoms")"
        fileName="$(UrlDecode "$fileName")"
        romUrl="$filteredWorldRoms"
        log "$processNumber/$platformToProcessNumber :: $platformName :: $romProcessNumber/$romListCount :: WORLD ROM FOUND ($fileName)"
    elif [ $filteredWorld2Romscount -eq 1 ]; then
        fileName="$(basename "$filteredWorld2Roms")"
        fileName="$(UrlDecode "$fileName")"
        romUrl="$filteredWorld2Roms"
        log "$processNumber/$platformToProcessNumber :: $platformName :: $romProcessNumber/$romListCount :: WORLD ROM FOUND ($fileName)"
    elif [ $filteredJapanRomscount -eq 1 ]; then
        fileName="$(basename "$filteredJapanRoms")"
        fileName="$(UrlDecode "$fileName")"
        romUrl="$filteredJapanRoms"
        log "$processNumber/$platformToProcessNumber :: $platformName :: $romProcessNumber/$romListCount :: JAPAN ROM FOUND ($fileName)"
    elif [ $filteredJapan2Romscount -eq 1 ]; then
        fileName="$(basename "$filteredJapan2Roms")"
        fileName="$(UrlDecode "$fileName")"
        romUrl="$filteredJapan2Roms"
        log "$processNumber/$platformToProcessNumber :: $platformName :: $romProcessNumber/$romListCount :: JAPAN ROM FOUND ($fileName)"
    elif [ $filteredOtherRomscount -eq 1 ]; then
        fileName="$(basename "$filteredOtherRoms")"
        fileName="$(UrlDecode "$fileName")"
        romUrl="$filteredOtherRoms"
        if [ ! -z "$fileName" ]; then
          log "$processNumber/$platformToProcessNumber :: $platformName :: $romProcessNumber/$romListCount :: OTHER ROM FOUND ($fileName)"
        fi
    fi

    if [ -z "$fileName" ]; then
      log "$processNumber/$platformToProcessNumber :: $platformName :: $romProcessNumber/$romListCount :: ERROR :: No Filtered Roms Found ($archiveContentsUrl)..."
      continue
    fi

    fileNameNoExt="${fileName%.*}"

    # verify download
    if [ -f "${outputdir}${subFolder}${fileName}" ]; then
        DownloadFileVerification "${outputdir}${subFolder}${fileName}"
    fi

    # download file
    if ! find "${outputdir}${subFolder}" -type f -iname "$fileNameNoExt.*" | grep -v ".st$" | read; then
      log "$processNumber/$platformToProcessNumber :: $platformName :: $romProcessNumber/$romListCount :: ${fileName} :: ROM downloading to \"${outputdir}${subFolder}\"..."
      #wget "$romUrl" -O "${outputdir}${subFolder}${fileName}"
      DownloadFile "$romUrl" "${outputdir}${subFolder}${fileName}" "$concurrentConnectionCount"

      # verify download
      if [ -f "${outputdir}${subFolder}${fileName}" ]; then
          DownloadFileVerification "${outputdir}${subFolder}${fileName}"
      fi
    else
        log "$processNumber/$platformToProcessNumber :: $platformName :: $romProcessNumber/$romListCount :: ${fileName} :: ROM previously downloaded..." 
    fi

    if [ -f "${outputdir}${subFolder}${fileName}" ]; then
      if [ "$uncompressRom" == "true" ]; then
        UncompressFile "${outputdir}${subFolder}${fileName}" "${outputdir}${subFolder}"
      fi
    fi

    # set permisions
    if [ -f "${outputdir}${subFolder}${fileName}" ]; then
      log "$processNumber/$platformToProcessNumber :: $platformName :: $romProcessNumber/$romListCount :: ${fileName} :: Setting Permissions to 666"
      chmod 666 "${outputdir}${subFolder}${fileName}"
    else
      log "$processNumber/$platformToProcessNumber :: $platformName :: $romProcessNumber/$romListCount :: ${outputdir}${subFolder} :: Setting Permissions to 666"
      chmod 666 "${outputdir}${subFolder}"/*
    fi

    if [ -f /config/romfilelist ]; then
        rm /config/romfilelist
    fi
  done
  downloadedRomCount=$(find "$outputdir" -type f | wc -l)
  log "$processNumber/$platformToProcessNumber :: $platformName :: $downloadedRomCount ROMS Successfully Downloaded!!"
done

DownloadRomCountSummary

exit

#!/usr/bin/env bash
# This script is for dev purposes
scriptVersion="1.0"
scriptName="RA-ROM-Downloader"

#### Import Settings
source /config/extended.conf


#### Funcitons
UrlDecode () { : "${*//+/ }"; echo -e "${_//%/\\x}"; }
CreatePlatformRomList () {
  if [ -f /config/romlist ]; then
     rm /config/romlist
  fi
  archiveUrl="$(wget -qO- "$1" | grep -io '<a href=['"'"'"][^"'"'"']*['"'"'"]' |   sed -e 's/^<a href=["'"'"']//i' -e 's/["'"'"']$//i' | sed 's/\///g' | sort -u | sed "s|^|$1|")"
  echo "$archiveUrl" | grep -v "\.\." | sort >> /config/romlist
}
DownloadFileVerification () {
  echo "$processNumber/$platformToProcessNumber :: $platform :: $romProcessNumber/$romListCount :: Verifing Download..."
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
      Log "No methdod to verify this type of file (iso,hex,wasm,sv)"
      verify="0"
      ;;
  esac
  
  if [ "$verify" != "0" ]; then
    echo "$processNumber/$platformToProcessNumber :: $platform :: $romProcessNumber/$romListCount :: ERROR :: Failed Verification!"
    rm "$1"
  else
    echo "$processNumber/$platformToProcessNumber :: $platform :: $romProcessNumber/$romListCount :: Download Verified!"
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
  echo "$processNumber/$platformToProcessNumber :: $platform"
  if [ $platform == "snes" ]; then
    PlatformSnes
  fi
  echo "$processNumber/$platformToProcessNumber :: $platform :: Finding ROMS..."
  CreatePlatformRomList "$platformArchiveContentsUrl"
  outputdir="$romPath/$platformFolder"

  romlist=$(cat /config/romlist)
  romListCount=$(echo "$romlist" | wc -l)
  echo "$processNumber/$platformToProcessNumber :: $platform :: $romListCount ROMS Found!"
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

    if echo "$subFolder" | grep "~" | read; then
        subFolder="/$(echo "$subFolder" | cut -d "~" -f 2)/"
    else
        subFolder="/"
    fi

    if [ ! -d "${outputdir}${subFolder}" ]; then
        echo "$processNumber/$platformToProcessNumber :: $platform :: $romProcessNumber/$romListCount :: Creating \"${subFolder}\" folder... "
        mkdir -p "${outputdir}${subFolder}"
        chmod 777 "${outputdir}${subFolder}"
    fi

    echo "$processNumber/$platformToProcessNumber :: $platform :: $romProcessNumber/$romListCount :: Searching ROM Folder"

    if [ $filteredUsaRomscount -eq 1 ]; then
        echo "$processNumber/$platformToProcessNumber :: $platform :: $romProcessNumber/$romListCount :: USA (U) ROM FOUND"
        fileName="$(basename "$filteredUsaRoms")"
        fileName="$(UrlDecode "$fileName")"
        echo "$processNumber/$platformToProcessNumber :: $platform :: $romProcessNumber/$romListCount :: ${outputdir}${subFolder}${fileName}"
        if [ ! -f "${outputdir}${subFolder}${fileName}" ]; then
            echo "$processNumber/$platformToProcessNumber :: $platform :: $romProcessNumber/$romListCount :: Downloading \"${fileName}\" ROM..."
            wget "$filteredUsaRoms" -O "${outputdir}${subFolder}${fileName}"
            DownloadFileVerification "${outputdir}${subFolder}${fileName}"
        fi
    elif [ $filteredUsa2Romscount -eq 1 ]; then
        echo "$processNumber/$platformToProcessNumber :: $platform :: $romProcessNumber/$romListCount :: USA (USA) ROM FOUND"
        fileName="$(basename "$filteredUsa2Roms")"
        fileName="$(UrlDecode "$fileName")"
        echo "$processNumber/$platformToProcessNumber :: $platform :: $romProcessNumber/$romListCount :: ${outputdir}${subFolder}${fileName}"
        if [ ! -f "${outputdir}${subFolder}${fileName}" ]; then
            echo "$processNumber/$platformToProcessNumber :: $platform :: $romProcessNumber/$romListCount :: Downloading \"${fileName}\" ROM..."
            wget "$filteredEuropRoms" -O "${outputdir}${subFolder}${fileName}"
            DownloadFileVerification "${outputdir}${subFolder}${fileName}"
        fi
    elif [ $filteredEuropRomscount -eq 1 ]; then
        echo "$processNumber/$platformToProcessNumber :: $platform :: $romProcessNumber/$romListCount :: EUROPE ROM FOUND"
        fileName="$(basename "$filteredEuropRoms")"
        fileName="$(UrlDecode "$fileName")"
        echo "$processNumber/$platformToProcessNumber :: $platform :: $romProcessNumber/$romListCount :: ${outputdir}${subFolder}${fileName}"
        if [ ! -f "${outputdir}${subFolder}${fileName}" ]; then
            echo "$processNumber/$platformToProcessNumber :: $platform :: $romProcessNumber/$romListCount :: Downloading \"${fileName}\" ROM..."
            wget "$filteredEuropRoms" -O "${outputdir}${subFolder}${fileName}"
            DownloadFileVerification "${outputdir}${subFolder}${fileName}"
        fi
    elif [ $filteredWorldRomscount -eq 1 ]; then
        echo "$processNumber/$platformToProcessNumber :: $platform :: $romProcessNumber/$romListCount :: WORLD ROM FOUND"
        fileName="$(basename "$filteredWorldRoms")"
        fileName="$(UrlDecode "$fileName")"
        echo "$processNumber/$platformToProcessNumber :: $platform :: $romProcessNumber/$romListCount :: ${outputdir}${subFolder}${fileName}"
        if [ ! -f "${outputdir}${subFolder}${fileName}" ]; then
            echo "$processNumber/$platformToProcessNumber :: $platform :: $romProcessNumber/$romListCount :: Downloading \"${fileName}\" ROM..."
            wget "$filteredWorldRoms" -O "${outputdir}${subFolder}${fileName}"
            DownloadFileVerification "${outputdir}${subFolder}${fileName}"
        fi
    elif [ $filteredJapanRomscount -eq 1 ]; then
        echo "$processNumber/$platformToProcessNumber :: $platform :: $romProcessNumber/$romListCount :: JAPAN ROM FOUND"
        fileName="$(basename "$filteredJapanRoms")"
        fileName="$(UrlDecode "$fileName")"
        echo "$processNumber/$platformToProcessNumber :: $platform :: $romProcessNumber/$romListCount :: ${outputdir}${subFolder}${fileName}"
        if [ ! -f "${outputdir}${subFolder}${fileName}" ]; then
            echo "$processNumber/$platformToProcessNumber :: $platform :: $romProcessNumber/$romListCount :: Downloading \"${fileName}\" ROM..."
            wget "$filteredJapanRoms" -O "${outputdir}${subFolder}${fileName}"
            DownloadFileVerification "${outputdir}${subFolder}${fileName}"
        fi
    elif [ $filteredOtherRomscount -eq 1 ]; then
        echo "$processNumber/$platformToProcessNumber :: $platform :: $romProcessNumber/$romListCount :: OTHER ROM FOUND"
        fileName="$(basename "$filteredOtherRoms")"
        fileName="$(UrlDecode "$fileName")"
        echo "$processNumber/$platformToProcessNumber :: $platform :: $romProcessNumber/$romListCount :: ${outputdir}${subFolder}${fileName}"
        if [ ! -f "${outputdir}${subFolder}${fileName}" ]; then
            echo "$processNumber/$platformToProcessNumber :: $platform :: $romProcessNumber/$romListCount :: Downloading \"${fileName}\" ROM..."
            wget "$filteredOtherRoms" -O "${outputdir}${subFolder}${fileName}"
            DownloadFileVerification "${outputdir}${subFolder}${fileName}"
        fi
    else
        echo "$processNumber/$platformToProcessNumber :: $platform :: $romProcessNumber/$romListCount :: ERROR :: No Filtered Roms Found..."
    fi

    if [ -f "${outputdir}${subFolder}${fileName}" ]; then
        echo "$processNumber/$platformToProcessNumber :: $platform :: $romProcessNumber/$romListCount :: Setting Permissions on: ${fileName}"
        chmod 666 "${outputdir}${subFolder}${fileName}"
    fi

    if [ -f /config/romfilelist ]; then
        rm /config/romfilelist
    fi
  done
done



exit

url="https://archive.org/download/retroachievements_collection_v5/SNES/Super%20Mario%20Kart/Super%20Mario%20Kart%20%28U%29%20%5B%21%5D.zip"
decodedUrl="$(UrlDecode "$url")"
echo $decodedUrl


url="https://archive.org/download/retroachievements_collection_v5/SNES"
decodedUrl="$(UrlDecode "$url")"
echo $decodedUrl


if [ -f romlist ]; then
    rm romlist
fi

if [ -f romfilelist ]; then
    rm romfilelist
fi

outputdir="/home/steveno/Nextcloud/Gaming/ROMs/megadrive"

archiveContentsUrl="https://archive.org/download/retroachievements_collection_v5/SNES/"



archiveContentsUrl="https://archive.org/download/retroachievements_collection_v5/NES/"


archiveContentsUrl="https://archive.org/download/retroachievements_collection_v5/Mega%20Drive/"
archiveUrl="$(wget -qO- "$archiveContentsUrl" | grep -io '<a href=['"'"'"][^"'"'"']*['"'"'"]' |   sed -e 's/^<a href=["'"'"']//i' -e 's/["'"'"']$//i' | sed 's/\///g' | sort -u | sed "s|^|$archiveContentsUrl|")"
echo "$archiveUrl" | grep -v "\.\." | sort >> romlist
romlist=$(cat romlist)
echo "$romlist" | while read -r rom; do
    archiveContentsUrl="$rom/"
    archiveUrl="$(wget -qO- "$archiveContentsUrl" | grep -i ".zip" |  grep -io '<a href=['"'"'"][^"'"'"']*['"'"'"]' |   sed -e 's/^<a href=["'"'"']//i' -e 's/["'"'"']$//i' | sed 's/\///g' | sort -u | sed "s|^|$archiveContentsUrl|")"
    echo "$archiveUrl" >> romfilelist
    romfiles="$(cat romfilelist | awk '{ print length, $0 }' | sort -n | cut -d" " -f2-)"
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

    if echo "$subFolder" | grep "~" | read; then
        subFolder="/$(echo "$subFolder" | cut -d "~" -f 2)/"
    else
        subFolder="/"
    fi

    if [ ! -d "${outputdir}${subFolder}" ]; then
        echo "Creating \"${subFolder}\" folder... "
        mkdir -p "${outputdir}${subFolder}"
        chmod 777 "${outputdir}${subFolder}"
    fi

    if [ $filteredUsaRomscount -eq 1 ]; then
        echo "USA (U) ROM FOUND"
        fileName="$(basename "$filteredUsaRoms")"
        fileName="$(UrlDecode "$fileName")"
        echo "${outputdir}${subFolder}${fileName}"
        if [ ! -f "${outputdir}${subFolder}${fileName}" ]; then
            wget "$filteredUsaRoms" -O "${outputdir}${subFolder}${fileName}"
            DownloadFileVerification "${outputdir}${subFolder}${fileName}"
        fi
    elif [ $filteredUsa2Romscount -eq 1 ]; then
        echo "USA (USA) ROM FOUND"
        fileName="$(basename "$filteredUsa2Roms")"
        fileName="$(UrlDecode "$fileName")"
        echo "${outputdir}${subFolder}${fileName}"
        if [ ! -f "${outputdir}${subFolder}${fileName}" ]; then
            wget "$filteredEuropRoms" -O "${outputdir}${subFolder}${fileName}"
            DownloadFileVerification "${outputdir}${subFolder}${fileName}"
        fi
    elif [ $filteredEuropRomscount -eq 1 ]; then
        echo "EUROPE ROM FOUND"
        fileName="$(basename "$filteredEuropRoms")"
        fileName="$(UrlDecode "$fileName")"
        echo "${outputdir}${subFolder}${fileName}"
        if [ ! -f "${outputdir}${subFolder}${fileName}" ]; then
            wget "$filteredEuropRoms" -O "${outputdir}${subFolder}${fileName}"
            DownloadFileVerification "${outputdir}${subFolder}${fileName}"
        fi
    elif [ $filteredWorldRomscount -eq 1 ]; then
        echo "WORLD ROM FOUND"
        fileName="$(basename "$filteredWorldRoms")"
        fileName="$(UrlDecode "$fileName")"
        echo "${outputdir}${subFolder}${fileName}"
        if [ ! -f "${outputdir}${subFolder}${fileName}" ]; then
            wget "$filteredWorldRoms" -O "${outputdir}${subFolder}${fileName}"
            DownloadFileVerification "${outputdir}${subFolder}${fileName}"
        fi
    elif [ $filteredJapanRomscount -eq 1 ]; then
        echo "JAPAN ROM FOUND"
        fileName="$(basename "$filteredJapanRoms")"
        fileName="$(UrlDecode "$fileName")"
        echo "${outputdir}${subFolder}${fileName}"
        if [ ! -f "${outputdir}${subFolder}${fileName}" ]; then
            wget "$filteredJapanRoms" -O "${outputdir}${subFolder}${fileName}"
            DownloadFileVerification "${outputdir}${subFolder}${fileName}"
        fi
    elif [ $filteredOtherRomscount -eq 1 ]; then
        echo "OTHER ROM FOUND"
        fileName="$(basename "$filteredOtherRoms")"
        fileName="$(UrlDecode "$fileName")"
        echo "${outputdir}${subFolder}${fileName}"
        if [ ! -f "${outputdir}${subFolder}${fileName}" ]; then
            wget "$filteredOtherRoms" -O "${outputdir}${subFolder}${fileName}"
            DownloadFileVerification "${outputdir}${subFolder}${fileName}"
        fi
    else
        echo "ERROR :: No Filtered Roms Found..."
    fi

    if [ -f "${outputdir}${subFolder}${fileName}" ]; then
        echo "Setting Permissions on: ${fileName}"
        chmod 666 "${outputdir}${subFolder}${fileName}"
    fi

    if [ -f romfilelist ]; then
        rm romfilelist
    fi

done

exit
archiveContentsUrl="https://archive.org/download/retroachievements_collection_v5/SNES/World Heroes/"
archiveUrl="$(wget -qO- "$archiveContentsUrl" | grep -i ".zip" |  grep -io '<a href=['"'"'"][^"'"'"']*['"'"'"]' |   sed -e 's/^<a href=["'"'"']//i' -e 's/["'"'"']$//i' | sed 's/\///g' | sort -u | sed "s|^|$archiveContentsUrl|")"
echo "$(UrlDecode "$archiveUrl")" >> romfilelist
romfiles=$(cat romfilelist)
echo "$romfiles"
echo ""

if [ -f romlist ]; then
    rm romlist
fi

if [ -f romfilelist ]; then
    rm romfilelist
fi

exit
#curl -s "https://archive.org/download/retroachievements_collection_v5/SNES/Super%20Mario%20Kart/Super%20Mario%20Kart%20%28U%29%20%5B%21%5D.zip"

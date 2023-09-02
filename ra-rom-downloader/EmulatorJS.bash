#!/usr/bin/with-contenv bash
scriptVersion="1.0"
scriptName="EmulatorJS"

#### Import Settings
source /config/extended.conf
downloadPath="$romPath/RA_collection"
emulatorjsPath="$romPath/emulatorjs"

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

log () {
  m_time=`date "+%F %T"`
  echo $m_time" :: $scriptName :: $scriptVersion :: "$1 2>&1 | tee -a /config/$scriptName.log
}

ProcessRoms () {
OIFS="$IFS"
IFS=$'\n'
for folder in $(ls "$1"); do
    romFolder="$1/$folder"
    romFiles="$(ls "$romFolder" | sort -hr)"
    if echo "$romFiles" | grep -i " (U)" | head -n 1 | read; then
        log "USA ROM FOUND"
        romFile="$(echo "$romFiles" | grep -i " (U)" | head -n 1)"
        CreateHardLink "$romFolder/$romFile"
    elif echo "$romFiles" | grep -i " (USA)" | head -n 1 | read; then
        log "USA ROM FOUND"
        romFile="$(echo "$romFiles" | grep -i " (USA)" | head -n 1)"
        CreateHardLink "$romFolder/$romFile"
    elif echo "$romFiles" | grep -i " (UE)" | head -n 1 | read; then
        log "USA ROM FOUND"
        romFile="$(echo "$romFiles" | grep -i " (UE)" | head -n 1)"
        CreateHardLink "$romFolder/$romFile"
    elif echo "$romFiles" | grep -i " (E)" | head -n 1 | read; then
        log "EUROPE ROM FOUND"
        romFile="$(echo "$romFiles" | grep -i " (E)" | head -n 1)"
        CreateHardLink "$romFolder/$romFile"
    elif echo "$romFiles" | grep -i " (Europe)" | head -n 1 | read; then
        log "EUROPE ROM FOUND"
        romFile="$(echo "$romFiles" | grep -i " (Europe)" | head -n 1)"
        CreateHardLink "$romFolder/$romFile"
    elif echo "$romFiles" | grep -i " (W)" | head -n 1 | read; then
        log "WORLD ROM FOUND"
        romFile="$(echo "$romFiles" | grep -i " (W)" | head -n 1)"
        CreateHardLink "$romFolder/$romFile"
    elif echo "$romFiles" | grep -i " (World)" | head -n 1 | read; then
        log "WORLD ROM FOUND"
        romFile="$(echo "$romFiles" | grep -i " (World)" | head -n 1)"
        CreateHardLink "$romFolder/$romFile"
    elif echo "$romFiles" | grep -i " (J)" | head -n 1 | read; then
        log "JAPAN ROM FOUND"
        romFile="$(echo "$romFiles" | grep -i " (J)" | head -n 1)"
        CreateHardLink "$romFolder/$romFile"
    elif echo "$romFiles" | grep -i " (Japan)" | head -n 1 | read; then
        log "JAPAN ROM FOUND"
        romFile="$(echo "$romFiles" | grep -i " (Japan)" | head -n 1)"
        CreateHardLink "$romFolder/$romFile"
    elif echo "$romFiles" | grep -i ".zip" | head -n 1 | read; then
        log "OTHER ROM FOUND"
        romFile="$(echo "$romFiles" | grep -i ".zip" | head -n 1)"
        CreateHardLink "$romFolder/$romFile"
    fi
done
IFS="$OIFS"
}

CreateHardLink () {
    log "$emulatorJsPlatformFolder"
    romFileName="$(basename "$1")"
    log "$romFileName"
    if [ ! -d "$emulatorjsPath/$emulatorJsPlatformFolder" ]; then
        mkdir -p "$emulatorjsPath/$emulatorJsPlatformFolder" 
        chmod 777 "$emulatorjsPath/$emulatorJsPlatformFolder" 
    fi
    if [ ! -f "$emulatorjsPath/$emulatorJsPlatformFolder/roms/$romFileName" ]; then
        log "Create link"
        ln "$1" "$emulatorjsPath/$emulatorJsPlatformFolder/roms/$romFileName"
        chmod 666
    else
        log "Link Exists, skipping..."
    fi
}


########################################################## SCRIPT START "##########################################################
logfileSetup

if [ ! -d "$emulatorjsPath" ]; then
    log "ERROR :: Emulatorjs path does not exist..."
    exit
fi

log "##########################################################"
log "Processing NES ROMS"
raFolder="$romPath/RA_collection/NES" 
emulatorJsPlatformFolder="nes"
if [ -d "$raFolder" ]; then
    ProcessRoms "$raFolder" "$emulatorJsPlatformFolder"
fi
log "##########################################################"
sleep 2


log "Processing Game Boy ROMS"
raFolder="$romPath/RA_collection/Game Boy" 
emulatorJsPlatformFolder="gb"
if [ -d "$raFolder" ]; then
    ProcessRoms "$raFolder" "$emulatorJsPlatformFolder"
fi
log "##########################################################"
sleep 2

log "Processing Game Boy Color ROMS"
raFolder="$romPath/RA_collection/Game Boy Color" 
emulatorJsPlatformFolder="gbc"
if [ -d "$raFolder" ]; then
    ProcessRoms "$raFolder" "$emulatorJsPlatformFolder"
fi
log "##########################################################"

log "Processing Game Boy Advance ROMS"
raFolder="$romPath/RA_collection/Game Boy Advance" 
emulatorJsPlatformFolder="gba"
if [ -d "$raFolder" ]; then
    ProcessRoms "$raFolder" "$emulatorJsPlatformFolder"
fi
log "##########################################################"
sleep 2

log "Processing Game Gear ROMS"
raFolder="$romPath/RA_collection/Game Gear" 
emulatorJsPlatformFolder="segaGG"
if [ -d "$raFolder" ]; then
    ProcessRoms "$raFolder" "$emulatorJsPlatformFolder"
fi
log "##########################################################"
sleep 2

log "Processing SNES ROMS"
raFolder="$romPath/RA_collection/SNES" 
emulatorJsPlatformFolder="snes"
if [ -d "$raFolder" ]; then
    ProcessRoms "$raFolder" "$emulatorJsPlatformFolder"
fi
log "##########################################################"
sleep 2

log "Processing Virtual Boy ROMS"
raFolder="$romPath/RA_collection/Virtual Boy" 
emulatorJsPlatformFolder="vb"
if [ -d "$raFolder" ]; then
    ProcessRoms "$raFolder" "$emulatorJsPlatformFolder"
fi
log "##########################################################"
sleep 2

log "Processing Vectrex ROMS"
raFolder="$romPath/RA_collection/Vectrex" 
emulatorJsPlatformFolder="vectrex"
if [ -d "$raFolder" ]; then
    ProcessRoms "$raFolder" "$emulatorJsPlatformFolder"
fi
log "##########################################################"
sleep 2

log "Processing Mega Drive ROMS"
raFolder="$romPath/RA_collection/Mega Drive" 
emulatorJsPlatformFolder="segaMD"
if [ -d "$raFolder" ]; then
    ProcessRoms "$raFolder" "$emulatorJsPlatformFolder"
fi
log "##########################################################"
sleep 2

log "Processing Master System ROMS"
raFolder="$romPath/RA_collection/Master System" 
emulatorJsPlatformFolder="segaMS"
if [ -d "$raFolder" ]; then
    ProcessRoms "$raFolder" "$emulatorJsPlatformFolder"
fi
log "##########################################################"
sleep 2

log "Processing Nintendo 64 ROMS"
raFolder="$romPath/RA_collection/Nintendo 64" 
emulatorJsPlatformFolder="n64"
if [ -d "$raFolder" ]; then
    ProcessRoms "$raFolder" "$emulatorJsPlatformFolder"
fi
log "##########################################################"
sleep 2

log "Processing Atari 2600 ROMS"
raFolder="$romPath/RA_collection/Atari 2600" 
emulatorJsPlatformFolder="atari2600"
if [ -d "$raFolder" ]; then
    ProcessRoms "$raFolder" "$emulatorJsPlatformFolder"
fi
log "##########################################################"
sleep 2

log "Processing Atari 7800 ROMS"
raFolder="$romPath/RA_collection/Atari 7800" 
emulatorJsPlatformFolder="atari7800"
if [ -d "$raFolder" ]; then
    ProcessRoms "$raFolder" "$emulatorJsPlatformFolder"
fi
log "##########################################################"
sleep 2

log "Processing Atari Lynx ROMS"
raFolder="$romPath/RA_collection/Atari Lynx" 
emulatorJsPlatformFolder="lynx"
if [ -d "$raFolder" ]; then
    ProcessRoms "$raFolder" "$emulatorJsPlatformFolder"
fi
log "##########################################################"
sleep 2

log "Processing ColecoVision ROMS"
raFolder="$romPath/RA_collection/ColecoVision" 
emulatorJsPlatformFolder="colecovision"
if [ -d "$raFolder" ]; then
    ProcessRoms "$raFolder" "$emulatorJsPlatformFolder"
fi
log "##########################################################"
sleep 2

log "Processing Magnavox Odyssey 2 ROMS"
raFolder="$romPath/RA_collection/Magnavox Odyssey 2" 
emulatorJsPlatformFolder="odyssey2"
if [ -d "$raFolder" ]; then
    ProcessRoms "$raFolder" "$emulatorJsPlatformFolder"
fi
log "##########################################################"
sleep 2

log "Processing Atari Jaguar ROMS"
raFolder="$romPath/RA_collection/Atari Jaguar" 
emulatorJsPlatformFolder="jaguar"
if [ -d "$raFolder" ]; then
    ProcessRoms "$raFolder" "$emulatorJsPlatformFolder"
fi
log "##########################################################"
sleep 2

log "Processing Neo Geo Pocket ROMS"
raFolder="$romPath/RA_collection/Neo Geo Pocket" 
emulatorJsPlatformFolder="ngp"
if [ -d "$raFolder" ]; then
    ProcessRoms "$raFolder" "$emulatorJsPlatformFolder"
fi
log "##########################################################"
sleep 2

log "Processing WonderSwan ROMS"
raFolder="$romPath/RA_collection/WonderSwan" 
emulatorJsPlatformFolder="ws"
if [ -d "$raFolder" ]; then
    ProcessRoms "$raFolder" "$emulatorJsPlatformFolder"
fi
log "##########################################################"
sleep 2

log "Processing Sega 32X ROMS"
raFolder="$romPath/RA_collection/32X" 
emulatorJsPlatformFolder="sega32x"
if [ -d "$raFolder" ]; then
    ProcessRoms "$raFolder" "$emulatorJsPlatformFolder"
fi
log "##########################################################"
sleep 2



exit

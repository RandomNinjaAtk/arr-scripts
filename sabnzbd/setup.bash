#!/usr/bin/with-contenv bash
scriptVersion="1.5"

######## Package dependencies installation
InstallRequirements () {
  echo "Installing Required Packages..."
  echo "************ install and update packages ************"
	apk add  -U --update --no-cache \
		flac \
		opus-tools \
		jq \
		git \
		ffmpeg
	apk add mp3val --repository=https://dl-cdn.alpinelinux.org/alpine/edge/testing
	echo "*** install beets ***"
	apk add --no-cache -X http://dl-cdn.alpinelinux.org/alpine/edge/community beets
	echo "************ install python packages ************"
	pip install --upgrade --no-cache-dir -U \
		m4b-merge \
		pyacoustid \
		requests \
		pylast \
		mutagen \
    r128gain
  echo "Done"
  if [ -d /config/scripts/sma ]; then
    rm -rf /config/scripts/sma
  fi
  echo "************ setup SMA ************"
  echo "************ setup directory ************"
  mkdir -p /config/scripts/sma
  echo "************ download repo ************"
  git clone https://github.com/mdhiggins/sickbeard_mp4_automator.git /config/scripts/sma
  mkdir -p /config/scripts/sma/config
  echo "************ create logging file ************"
  mkdir -p /config/scripts/sma/config
  touch /config/scripts/sma/config/sma.log
  echo "************ install pip dependencies ************"
  pip install --upgrade pip --no-cache-dir 
  pip install -r /config/scripts/sma/setup/requirements.txt --no-cache-dir 
  chmod 777 -R /config/scripts/sma
}

echo "Setup Script Version: $scriptVersion"
InstallRequirements

mkdir -p /config/scripts
chmod 777 /config/scripts
echo "Downloading SMA config: /config/scripts/sma.ini"
curl "https://raw.githubusercontent.com/RandomNinjaAtk/arr-scripts/main/sabnzbd/sma.ini" -o /config/sma.ini
if [ -f /config/sma.ini ]; then
  if [ -f /config/scripts/sma.ini ]; then
    echo "Removing /config/scripts/sma.ini"
    rm /config/scripts/sma.ini 
  fi
  echo "Importing /config/sma.ini to /config/scripts/sma.ini"
  mv /config/sma.ini /config/scripts/sma.ini 
  chmod 777 /config/scripts/sma.ini 
fi

echo "Downloading Video script: /config/scripts/video.bash"
curl "https://raw.githubusercontent.com/RandomNinjaAtk/arr-scripts/main/sabnzbd/video.bash" -o /config/video.bash

if [ -f /config/video.bash ]; then
  if [ -f /config/scripts/video.bash ]; then
    echo "Removing /config/scripts/video.bash"
    rm /config/scripts/video.bash 
  fi
  echo "Importing /config/video.bash to /config/scripts/video.bash"
  mv /config/video.bash /config/scripts/video.bash 
  chmod 777 /config/scripts/video.bash 
fi 

echo "Downloading Audio script: /config/scripts/audio.bash"
curl "https://raw.githubusercontent.com/RandomNinjaAtk/arr-scripts/main/sabnzbd/audio.bash" -o /config/audio.bash

if [ -f /config/audio.bash ]; then
  if [ -f /config/scripts/audio.bash ]; then
    echo "Removing /config/scripts/audio.bash"
    rm /config/scripts/video.bash 
  fi
  echo "Importing /config/audio.bash to /config/scripts/audio.bash"
  mv /config/audio.bash /config/scripts/audio.bash 
  chmod 777 /config/scripts/audio.bash 
fi  

chmod 777 -R /config/scripts
exit

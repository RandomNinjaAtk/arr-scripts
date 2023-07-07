#!/usr/bin/with-contenv bash
scriptVersion="1.0"

######## Package dependencies installation
InstallRequirements () {
  echo "Installing Required Packages..."
  apk add -U --update --no-cache curl jq python3-dev py3-pip git ffmpeg
  pip install --upgrade --no-cache-dir -U yq
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

InstallRequirements

mkdir -p /config/scripts
chmod 777 /config/scripts
echo "Downloading SMA config: /config/scripts/sma.ini"
curl https://raw.githubusercontent.com/RandomNinjaAtk/arr-scripts/main/sabnzbd/sma.ini -O /config/scripts/sma.ini
echo "Downloading Video script config: /config/scripts/video.bash"
curl https://raw.githubusercontent.com/RandomNinjaAtk/arr-scripts/main/sabnzbd/video.bash -O /config/scripts/video.bash
chmod 777 -R /config/scripts
exit

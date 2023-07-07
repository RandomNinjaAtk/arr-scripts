#!/usr/bin/with-contenv bash

######## Package dependencies installation
InstallRequirements () {
  echo "Installing Required Packages..."
  apk add -U --update --no-cache curl jq python3-dev py3-pip git ffmpeg &>/dev/null
  pip install --upgrade --no-cache-dir -U yq &>/dev/null
  echo "Done"
  
  if [ ! -f /config/scripts/sma/manual.py ]; then
    echo "************ setup SMA ************"
  	echo "************ setup directory ************"
  	mkdir -p /config/scripts/sma
  	echo "************ download repo ************"
  	git clone https://github.com/mdhiggins/sickbeard_mp4_automator.git /config/scripts/sma
  	mkdir -p /config/scripts/sma/config
  	echo "************ create logging file ************"
  	mkdir -p /config/scripts/sma/config
  	touch /config/scripts/sma/config/sma.log
  	chgrp users /config/scripts/sma/config/sma.log
  	chmod g+w /config/scripts/sma/config/sma.log
  	echo "************ install pip dependencies ************"
  	pip install --upgrade pip --no-cache-dir 
   	pip install -r /config/scripts/sma/setup/requirements.txt --no-cache-dir 
	chmod 777 -R /config/scripts/sma
  fi
}

InstallRequirements

exit

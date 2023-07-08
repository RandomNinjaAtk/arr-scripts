#!/usr/bin/with-contenv bash
SMA_PATH="/usr/local/sma"

echo "************ install packages ************" && \
apk add -U --update --no-cache \
	flac \
	opus-tools \
	jq \
	git \
	wget \
	mkvtoolnix \
	python3-dev \
	libc-dev \
	py3-pip \
	gcc \
	ffmpeg \
	yt-dlp && \
echo "************ install python packages ************" && \
pip install --upgrade --no-cache-dir -U \
	excludarr \
	yq && \
echo "************ setup SMA ************" && \
echo "************ setup directory ************" && \
mkdir -p ${SMA_PATH} && \
echo "************ download repo ************" && \
git clone https://github.com/mdhiggins/sickbeard_mp4_automator.git ${SMA_PATH} && \
mkdir -p ${SMA_PATH}/config && \
echo "************ create logging file ************" && \
mkdir -p ${SMA_PATH}/config && \
touch ${SMA_PATH}/config/sma.log && \
chgrp users ${SMA_PATH}/config/sma.log && \
chmod g+w ${SMA_PATH}/config/sma.log && \
echo "************ install pip dependencies ************" && \
python3 -m pip install --user --upgrade pip && \	
pip3 install -r ${SMA_PATH}/setup/requirements.txt && \
echo "************ install recyclarr ************" && \
mkdir -p /recyclarr && \
wget "https://github.com/recyclarr/recyclarr/releases/latest/download/recyclarr-linux-musl-x64.tar.xz" -O "/recyclarr/recyclarr.tar.xz" && \
tar -xf /recyclarr/recyclarr.tar.xz -C /recyclarr &>/dev/null && \
chmod 777 /recyclarr/recyclarr

mkdir -p /custom-services.d
curl https://raw.githubusercontent.com/RandomNinjaAtk/arr-scripts/main/universal/services/QueueCleaner -O /custom-services.d/

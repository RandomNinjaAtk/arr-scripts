#!/usr/bin/with-contenv bash
SMA_PATH="/usr/local/sma"
version="1.3"

echo "*** install packages ***" && \
apk add -U --upgrade --no-cache \
  tidyhtml \
  musl-locales \
  musl-locales-lang \
  flac \
  jq \
  git \
  gcc \
  ffmpeg \
  imagemagick \
  opus-tools \
  opustags \
  python3-dev \
  libc-dev \
  py3-pip \
  npm && \
echo "*** install freyr client ***" && \
apk add --no-cache -X http://dl-cdn.alpinelinux.org/alpine/edge/testing atomicparsley && \
npm install -g miraclx/freyr-js &&\
echo "*** install python packages ***" && \
pip install --upgrade --no-cache-dir --break-system-packages \
  jellyfish \
  beautifulsoup4 \
  yt-dlp \
  beets \
  yq \
  pyxDamerauLevenshtein \
  pyacoustid \
  requests \
  colorama \
  python-telegram-bot \
  pylast \
  mutagen \
  r128gain \
  tidal-dl \
  deemix && \
echo "************ setup SMA ************"
if [ -d "${SMA_PATH}"  ]; then
  rm -rf "${SMA_PATH}"
fi
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
python3 -m pip install --break-system-packages --upgrade pip && \
pip3 install --break-system-packages -r ${SMA_PATH}/setup/requirements.txt

mkdir -p /custom-services.d

echo "Download QueueCleaner service..."
curl https://raw.githubusercontent.com/RandomNinjaAtk/arr-scripts/main/universal/services/QueueCleaner -o /custom-services.d/QueueCleaner
echo "Done"

echo "Download AutoConfig service..."
curl https://raw.githubusercontent.com/RandomNinjaAtk/arr-scripts/main/lidarr/AutoConfig.service.bash -o /custom-services.d/AutoConfig
echo "Done"

echo "Download Video service..."
curl https://raw.githubusercontent.com/RandomNinjaAtk/arr-scripts/main/lidarr/Video.service.bash -o /custom-services.d/Video
echo "Done"

echo "Download Tidal Video Downloader service..."
curl https://raw.githubusercontent.com/RandomNinjaAtk/arr-scripts/main/lidarr/TidalVideoDownloader.bash -o /custom-services.d/TidalVideoDownloader
echo "Done"

echo "Download Audio service..."
curl https://raw.githubusercontent.com/RandomNinjaAtk/arr-scripts/main/lidarr/Audio.service.bash -o /custom-services.d/Audio
echo "Done"

echo "Download AutoArtistAdder service..."
curl https://raw.githubusercontent.com/RandomNinjaAtk/arr-scripts/main/lidarr/AutoArtistAdder.bash -o /custom-services.d/AutoArtistAdder
echo "Done"

echo "Download UnmappedFilesCleaner service..."
curl https://raw.githubusercontent.com/RandomNinjaAtk/arr-scripts/main/lidarr/UnmappedFilesCleaner.bash -o /custom-services.d/UnmappedFilesCleaner
echo "Done"

mkdir -p /custom-services.d/python
echo "Download ARLChecker service..."
curl https://raw.githubusercontent.com/RandomNinjaAtk/arr-scripts/main/lidarr/python/ARLChecker.py -o /custom-services.d/python/ARLChecker.py
curl https://raw.githubusercontent.com/RandomNinjaAtk/arr-scripts/main/lidarr/ARLChecker -o /custom-services.d/ARLChecker



echo "Done"

mkdir -p /config/extended
echo "Download Script Functions..."
curl https://raw.githubusercontent.com/RandomNinjaAtk/arr-scripts/main/universal/functions.bash -o /config/extended/functions
echo "Done"

echo "Download PlexNotify script..."
curl https://raw.githubusercontent.com/RandomNinjaAtk/arr-scripts/main/lidarr/PlexNotify.bash -o /config/extended/PlexNotify.bash 
echo "Done"

echo "Download SMA config..."
curl https://raw.githubusercontent.com/RandomNinjaAtk/arr-scripts/main/lidarr/sma.ini -o /config/extended/sma.ini 
echo "Done"

if [ ! -f /config/extended/beets-config.yaml ]; then
	echo "Download Beets config..."
	curl "https://raw.githubusercontent.com/RandomNinjaAtk/arr-scripts/main/lidarr/beets-config.yaml" -o /config/extended/beets-config.yaml
	echo "Done"
fi

if [ ! -f /config/extended/beets-config-lidarr.yaml ]; then
	echo "Download Beets lidarr config..."
	curl "https://raw.githubusercontent.com/RandomNinjaAtk/arr-scripts/main/lidarr/beets-config-lidarr.yaml" -o /config/extended/beets-config-lidarr.yaml
	echo "Done"
fi

echo "Download Deemix config..."
curl "https://raw.githubusercontent.com/RandomNinjaAtk/arr-scripts/main/lidarr/deemix_config.json" -o /config/extended/deemix_config.json
echo "Done"

echo "Download Tidal config..."
curl "https://raw.githubusercontent.com/RandomNinjaAtk/arr-scripts/main/lidarr/tidal-dl.json" -o /config/extended/tidal-dl.json
echo "Done"

echo "Download LyricExtractor script..."
curl https://raw.githubusercontent.com/RandomNinjaAtk/arr-scripts/main/lidarr/LyricExtractor.bash -o /config/extended/LyricExtractor.bash
echo "Done"

echo "Download ArtworkExtractor script..."
curl https://raw.githubusercontent.com/RandomNinjaAtk/arr-scripts/main/lidarr/ArtworkExtractor.bash -o /config/extended/ArtworkExtractor.bash
echo "Done"

echo "Download Beets Tagger script..."
curl https://raw.githubusercontent.com/RandomNinjaAtk/arr-scripts/main/lidarr/BeetsTagger.bash -o /config/extended/BeetsTagger.bash
echo "Done"

if [ ! -f /config/extended/beets-genre-whitelist.txt ]; then
	echo "Download beets-genre-whitelist.txt..."
	curl https://raw.githubusercontent.com/RandomNinjaAtk/arr-scripts/main/lidarr/beets-genre-whitelist.txt -o /config/extended/beets-genre-whitelist.txt
	echo "Done"
fi

if [ ! -f /config/extended.conf ]; then
	echo "Download Extended config..."
	curl https://raw.githubusercontent.com/RandomNinjaAtk/arr-scripts/main/lidarr/extended.conf -o /config/extended.conf
	chmod 777 /config/extended.conf
	echo "Done"
fi

chmod 777 -R /config/extended
chmod 777 -R /root

if [ -f /custom-services.d/scripts_init.bash ]; then
   # user misconfiguration detected, sleeping...
   sleep infinity
fi
exit

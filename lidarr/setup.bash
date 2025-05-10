#!/usr/bin/with-contenv bash
set -euo pipefail

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
  uv \
  parallel \
  npm && \
echo "*** install freyr client ***" && \
apk add --no-cache -X http://dl-cdn.alpinelinux.org/alpine/edge/testing atomicparsley && \
npm install -g miraclx/freyr-js &&\
echo "*** install python packages ***" && \
uv pip install --system --upgrade --no-cache-dir --break-system-packages \
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
echo "************ download repo ************" && \
git clone --depth 1 https://github.com/mdhiggins/sickbeard_mp4_automator.git ${SMA_PATH} && \
echo "************ create logging file ************" && \
touch ${SMA_PATH}/config/sma.log && \
chgrp users ${SMA_PATH}/config/sma.log && \
chmod g+w ${SMA_PATH}/config/sma.log && \
echo "************ install pip dependencies ************" && \
uv pip install --system --break-system-packages -r ${SMA_PATH}/setup/requirements.txt

mkdir -p /custom-services.d/python /config/extended

parallel ::: \
  'echo "Download QueueCleaner service..." && curl -sfL https://raw.githubusercontent.com/RandomNinjaAtk/arr-scripts/main/universal/services/QueueCleaner -o /custom-services.d/QueueCleaner && echo "Done"' \
  'echo "Download AutoConfig service..." && curl -sfL https://raw.githubusercontent.com/RandomNinjaAtk/arr-scripts/main/lidarr/AutoConfig.service.bash -o /custom-services.d/AutoConfig && echo "Done"' \
  'echo "Download Video service..." && curl -sfL https://raw.githubusercontent.com/RandomNinjaAtk/arr-scripts/main/lidarr/Video.service.bash -o /custom-services.d/Video && echo "Done"' \
  'echo "Download Tidal Video Downloader service..." && curl -sfL https://raw.githubusercontent.com/steve1977/arr-scripts/main/lidarr/TidalVideoDownloader.bash -o /custom-services.d/TidalVideoDownloader && echo "Done"' \
  'echo "Download Audio service..." && curl -sfL https://raw.githubusercontent.com/RandomNinjaAtk/arr-scripts/main/lidarr/Audio.service.bash -o /custom-services.d/Audio && echo "Done"' \
  'echo "Download AutoArtistAdder service..." && curl -sfL https://raw.githubusercontent.com/RandomNinjaAtk/arr-scripts/main/lidarr/AutoArtistAdder.bash -o /custom-services.d/AutoArtistAdder && echo "Done"' \
  'echo "Download UnmappedFilesCleaner service..." && curl -sfL https://raw.githubusercontent.com/RandomNinjaAtk/arr-scripts/main/lidarr/UnmappedFilesCleaner.bash -o /custom-services.d/UnmappedFilesCleaner && echo "Done"' \
  'echo "Download ARLChecker service..." && curl -sfL https://raw.githubusercontent.com/RandomNinjaAtk/arr-scripts/main/lidarr/python/ARLChecker.py -o /custom-services.d/python/ARLChecker.py && curl -sfL https://raw.githubusercontent.com/RandomNinjaAtk/arr-scripts/main/lidarr/ARLChecker -o /custom-services.d/ARLChecker && echo "Done"' \
  'echo "Download Script Functions..." && curl -sfL https://raw.githubusercontent.com/RandomNinjaAtk/arr-scripts/main/universal/functions.bash -o /config/extended/functions && echo "Done"' \
  'echo "Download PlexNotify script..." && curl -sfL https://raw.githubusercontent.com/RandomNinjaAtk/arr-scripts/main/lidarr/PlexNotify.bash -o /config/extended/PlexNotify.bash  && echo "Done"' \
  'echo "Download SMA config..." && curl -sfL https://raw.githubusercontent.com/RandomNinjaAtk/arr-scripts/main/lidarr/sma.ini -o /config/extended/sma.ini  && echo "Done"' \
  'echo "Download LyricExtractor script..." && curl -sfL https://raw.githubusercontent.com/RandomNinjaAtk/arr-scripts/main/lidarr/LyricExtractor.bash -o /config/extended/LyricExtractor.bash && echo "Done"' \
  'echo "Download ArtworkExtractor script..." && curl -sfL https://raw.githubusercontent.com/RandomNinjaAtk/arr-scripts/main/lidarr/ArtworkExtractor.bash -o /config/extended/ArtworkExtractor.bash && echo "Done"' \
  'echo "Download Beets Tagger script..." && curl -sfL https://raw.githubusercontent.com/RandomNinjaAtk/arr-scripts/main/lidarr/BeetsTagger.bash -o /config/extended/BeetsTagger.bash && echo "Done"'


if [ ! -f /config/extended/beets-config.yaml ]; then
	echo "Download Beets config..."
	curl -sfL "https://raw.githubusercontent.com/RandomNinjaAtk/arr-scripts/main/lidarr/beets-config.yaml" -o /config/extended/beets-config.yaml
	echo "Done"
fi

if [ ! -f /config/extended/beets-config-lidarr.yaml ]; then
	echo "Download Beets lidarr config..."
	curl -sfL "https://raw.githubusercontent.com/RandomNinjaAtk/arr-scripts/main/lidarr/beets-config-lidarr.yaml" -o /config/extended/beets-config-lidarr.yaml
	echo "Done"
fi

if [ ! -f /config/extended/deemix_config.json ]; then
  echo "Download Deemix config..."
  curl -sfL "https://raw.githubusercontent.com/RandomNinjaAtk/arr-scripts/main/lidarr/deemix_config.json" -o /config/extended/deemix_config.json
  echo "Done"
fi

if [ ! -f /config/extended/tidal-dl.json ]; then
  echo "Download Tidal config..."
  curl -sfL "https://raw.githubusercontent.com/RandomNinjaAtk/arr-scripts/main/lidarr/tidal-dl.json" -o /config/extended/tidal-dl.json
  echo "Done"
fi

if [ ! -f /config/extended/beets-genre-whitelist.txt ]; then
	echo "Download beets-genre-whitelist.txt..."
	curl -sfL https://raw.githubusercontent.com/RandomNinjaAtk/arr-scripts/main/lidarr/beets-genre-whitelist.txt -o /config/extended/beets-genre-whitelist.txt
	echo "Done"
fi

if [ ! -f /config/extended.conf ]; then
	echo "Download Extended config..."
	curl -sfL https://raw.githubusercontent.com/RandomNinjaAtk/arr-scripts/main/lidarr/extended.conf -o /config/extended.conf
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

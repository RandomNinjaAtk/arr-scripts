#!/usr/bin/with-contenv bash
SMA_PATH="/usr/local/sma"

echo "************ install packages ************"
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
	yt-dlp
echo "************ install python packages ************"
pip install --upgrade --no-cache-dir -U --break-system-packages \
	excludarr \
	yq
echo "************ setup SMA ************"
echo "************ setup directory ************"
if [ -d /config/extended/sma ]; then
	rm -rf /config/extended/sma
fi
mkdir -p /config/extended/sma
echo "************ download repo ************"
git clone https://github.com/mdhiggins/sickbeard_mp4_automator.git /config/extended/sma
mkdir -p /config/extended/sma/config
echo "************ create logging file ************"
mkdir -p /config/extended/sma/config
touch /config/extended/sma/config/sma.log
echo "************ install pip dependencies ************"
pip install --upgrade pip --no-cache-dir --break-system-packages
pip install -r /config/extended/sma/setup/requirements.txt --no-cache-dir --break-system-packages
chmod 777 -R /config/extended/sma
echo "************ install recyclarr ************"
mkdir -p /recyclarr
wget "https://github.com/recyclarr/recyclarr/releases/latest/download/recyclarr-linux-musl-x64.tar.xz" -O "/recyclarr/recyclarr.tar.xz"
tar -xf /recyclarr/recyclarr.tar.xz -C /recyclarr &>/dev/null
chmod 777 /recyclarr/recyclarr
apk add --no-cache -X http://dl-cdn.alpinelinux.org/alpine/edge/community dotnet7-runtime

mkdir -p /custom-services.d
echo "Download QueueCleaner service..."
curl https://raw.githubusercontent.com/RandomNinjaAtk/arr-scripts/main/universal/services/QueueCleaner -o /custom-services.d/QueueCleaner
echo "Done"

echo "Download AutoConfig service..."
curl https://raw.githubusercontent.com/RandomNinjaAtk/arr-scripts/main/sonarr/AutoConfig.service -o /custom-services.d/AutoConfig
echo "Done"

echo "Download AutoExtras service..."
curl https://raw.githubusercontent.com/RandomNinjaAtk/arr-scripts/main/sonarr/AutoExtras.service -o /custom-services.d/AutoExtras
echo "Done"

echo "Download InvalidSeriesAutoCleaner service..."
curl https://raw.githubusercontent.com/RandomNinjaAtk/arr-scripts/main/sonarr/InvalidSeriesAutoCleaner.service -o /custom-services.d/InvalidSeriesAutoCleaner
echo "Done"

echo "Download YoutubeSeriesDownloader service..."
curl https://raw.githubusercontent.com/RandomNinjaAtk/arr-scripts/main/sonarr/YoutubeSeriesDownloader.service -o /custom-services.d/YoutubeSeriesDownloader
echo "Done"

mkdir -p /config/extended
if [ ! -f /config/extended/naming.json ]; then
	echo "Download Naming script..."
	curl https://raw.githubusercontent.com/RandomNinjaAtk/arr-scripts/main/sonarr/naming.json -o /config/extended/naming.json 
	echo "Done"
fi

mkdir -p /config/extended
echo "Download Script Functions..."
curl https://raw.githubusercontent.com/RandomNinjaAtk/arr-scripts/main/universal/functions.bash -o /config/extended/functions
echo "Done"

echo "Download PlexNotify script..."
curl https://raw.githubusercontent.com/RandomNinjaAtk/arr-scripts/main/sonarr/PlexNotify.bash -o /config/extended/PlexNotify.bash 
echo "Done"

echo "Download DailySeriesEpisodeTrimmer script..."
curl https://raw.githubusercontent.com/RandomNinjaAtk/arr-scripts/main/sonarr/DailySeriesEpisodeTrimmer.bash -o /config/extended/DailySeriesEpisodeTrimmer.bash 
echo "Done"

echo "Download Extras script..."
curl https://raw.githubusercontent.com/RandomNinjaAtk/arr-scripts/main/sonarr/Extras.bash -o /config/extended/Extras.bash 
echo "Done"

if [ ! -f /config/extended/sma.ini ]; then
	echo "Download SMA config..."
	curl https://raw.githubusercontent.com/RandomNinjaAtk/arr-scripts/main/sonarr/sma.ini -o /config/extended/sma.ini 
	echo "Done"
fi

echo "Download Recyclarr service..."
curl https://raw.githubusercontent.com/RandomNinjaAtk/arr-scripts/main/universal/services/Recyclarr -o /custom-services.d/Recyclarr
echo "Done"

if [ ! -f /config/extended/recyclarr.yaml ]; then
	echo "Download Recyclarr config..."
	curl https://raw.githubusercontent.com/RandomNinjaAtk/arr-scripts/main/sonarr/recyclarr.yaml -o /config/extended/recyclarr.yaml
	echo "Done"
fi

if [ ! -f /config/extended.conf ]; then
	echo "Download Extended config..."
	curl https://raw.githubusercontent.com/RandomNinjaAtk/arr-scripts/main/sonarr/extended.conf -o /config/extended.conf
	chmod 777 /config/extended.conf
	echo "Done"
fi

chmod 777 -R /config/extended

exit

#!/usr/bin/with-contenv bash
RAHASHER_PATH="/usr/local/RALibretro"
echo "************ install dependencies ************"
echo "************ install and upgrade packages ************"
apt-get update
apt-get upgrade -y
apt-get install -y \
	jq \
	unzip \
	gzip \
	git \
	p7zip-full \
	curl \
	unrar \
	axel \
	zip \
 	wget \
  	python3-pip \
	bsdmainutils
echo "************ RAHasher installation ************"
mkdir -p ${RAHASHER_PATH}
wget "https://github.com/RetroAchievements/RALibretro/releases/download/1.4.0/RAHasher-x64-Linux-1.6.0.zip" -O "${RAHASHER_PATH}/rahasher.zip"
unzip "${RAHASHER_PATH}/rahasher.zip" -d ${RAHASHER_PATH}
chmod -R 777 ${RAHASHER_PATH}

mkdir -p /custom-services.d
echo "Download Downloader service..."
curl https://raw.githubusercontent.com/RandomNinjaAtk/arr-scripts/main/ra-rom-downloader/Downloader.bash -o /config/Downloader
echo "Done"
chmod 777 /custom-services.d/Downloader

if [ ! -f /config/extended.conf ]; then
	echo "Download Extended config..."
	curl https://raw.githubusercontent.com/RandomNinjaAtk/arr-scripts/main/ra-rom-downloader/extended.conf -o /config/extended.conf
	chmod 777 /config/extended.conf
	echo "Done"
fi

exit

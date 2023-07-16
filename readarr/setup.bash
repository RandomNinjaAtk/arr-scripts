#!/usr/bin/with-contenv bash
echo "************ install and update packages ************"
apk add -U --update --no-cache \
  jq \
  py3-pip && \
echo "************ install python packages ************"
pip install --upgrade --no-cache-dir -U yq

mkdir -p /custom-services.d
echo "Download AutoConfig service..."
curl https://raw.githubusercontent.com/RandomNinjaAtk/arr-scripts/main/readarr/AutoConfig.bash -o /custom-services.d/AutoConfig
echo "Done"

echo "Download QueueCleaner service..."
curl https://raw.githubusercontent.com/RandomNinjaAtk/arr-scripts/main/universal/services/QueueCleaner -o /custom-services.d/QueueCleaner
echo "Done"

mkdir -p /config/extended
echo "Download PlexNotify script..."
curl https://raw.githubusercontent.com/RandomNinjaAtk/arr-scripts/main/radarr/PlexNotify.bash -o /config/extended/PlexNotify.bash 
echo "Done"
exit

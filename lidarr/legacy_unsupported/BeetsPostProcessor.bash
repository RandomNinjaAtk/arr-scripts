#!/usr/bin/env bash
version=1.1
if [ -z "$lidarrUrl" ] || [ -z "$lidarrApiKey" ]; then
	lidarrUrlBase="$(cat /config/config.xml | xq | jq -r .Config.UrlBase)"
	if [ "$lidarrUrlBase" == "null" ]; then
		lidarrUrlBase=""
	else
		lidarrUrlBase="/$(echo "$lidarrUrlBase" | sed "s/\///g")"
	fi
	lidarrApiKey="$(cat /config/config.xml | xq | jq -r .Config.ApiKey)"
	lidarrPort="$(cat /config/config.xml | xq | jq -r .Config.Port)"
	lidarrUrl="http://127.0.0.1:${lidarrPort}${lidarrUrlBase}"
fi

log () {
    m_time=`date "+%F %T"`
    echo $m_time" :: BeetsPostProcessor :: $version :: "$1
}

# auto-clean up log file to reduce space usage
if [ -f "/config/logs/BeetsPostProcessor.txt" ]; then
	find /config/logs -type f -name "BeetsPostProcessor.txt" -size +1024k -delete
	sleep 0.5
fi
touch "/config/logs/BeetsPostProcessor.txt"
exec &> >(tee -a "/config/logs/BeetsPostProcessor.txt")
chmod 666 "/config/logs/BeetsPostProcessor.txt"

if [ "$lidarr_eventtype" == "Test" ]; then
	log "Tested Successfully"
	exit 0	
fi

getAlbumArtist="$(curl -s "$lidarrUrl/api/v1/album/$lidarr_album_id" -H "X-Api-Key: ${lidarrApiKey}" | jq -r .artist.artistName)"
getAlbumArtistPath="$(curl -s "$lidarrUrl/api/v1/album/$lidarr_album_id" -H "X-Api-Key: ${lidarrApiKey}" | jq -r .artist.path)"
getTrackPath="$(curl -s "$lidarrUrl/api/v1/trackFile?albumId=$lidarr_album_id" -H "X-Api-Key: ${lidarrApiKey}" | jq -r .[].path | head -n1)"
getFolderPath="$(dirname "$getTrackPath")"

if echo "$getFolderPath" | grep "$getAlbumArtistPath" | read; then
	if [ ! -d "$getFolderPath" ]; then
		log "ERROR :: \"$getFolderPath\" Folder is missing :: Exiting..."
	fi
else 
	log "ERROR :: $getAlbumArtistPath not found within \"$getFolderPath\" :: Exiting..."
	exit
fi

ProcessWithBeets () {

	SECONDS=0
	log "$1 :: Start Processing..."
	

	# Input
	# $1 Download Folder to process
	if [ -f /config/extended/library-postprocessor.blb ]; then
		rm /config/extended/library-postprocessor.blb
		sleep 0.5
	fi
	if [ -f /config/extended/extended/logs/beets.log ]; then 
		rm /config/extended/extended/logs/beets.log
		sleep 0.5
	fi

	if [ -f "/config/extended/beets-postprocessor-match" ]; then 
		rm "/config/extended/beets-postprocessor-match"
		sleep 0.5
	fi
	touch "/config/extended/beets-postprocessor-match"
	sleep 0.5

    log "$1 :: Being matching with beets!"
	beet -c /config/extended/beets-config-postprocessor.yaml -l /config/extended/library-postprocessor.blb -d "$1" import -qC "$1"
	if [ $(find "$1" -type f -regex ".*/.*\.\(flac\|opus\|m4a\|mp3\)" -newer "/config/extended/beets-postprocessor-match" | wc -l) -gt 0 ]; then
		log "$1 :: SUCCESS :: Matched with beets!"
		
		# Fix tags
		log "$1 :: Fixing Tags..."
		
		# Fix flac tags
		fixed=0
		find "$1" -type f -iname "*.flac" -print0 | while IFS= read -r -d '' file; do
			if [ $fixed == 0 ]; then
				fixed=$(( $fixed + 1 ))
				log "$1 :: Fixing Flac Tags..."
			fi
			getArtistCredit="$(ffprobe -loglevel 0 -print_format json -show_format -show_streams "$file" | jq -r ".format.tags.ARTIST_CREDIT" | sed "s/null//g" | sed "/^$/d")"
			metaflac --remove-tag=ARTIST "$file"
			metaflac --remove-tag=ALBUMARTIST "$file"
			metaflac --remove-tag=ALBUMARTIST_CREDIT "$file"
			metaflac --remove-tag=ALBUMARTISTSORT "$file"
			metaflac --remove-tag=ALBUM_ARTIST "$file"
			metaflac --remove-tag="ALBUM ARTIST" "$file"
			metaflac --remove-tag=ARTISTSORT "$file"
			metaflac --remove-tag=COMPOSERSORT "$file"
			metaflac --set-tag=ALBUMARTIST="$getAlbumArtist" "$file"
			if [ ! -z "$getArtistCredit" ]; then
        			metaflac --set-tag=ARTIST="$getArtistCredit" "$file"
			else
				metaflac --set-tag=ARTIST="$getAlbumArtist" "$file"
			fi
		done
		
		log "$1 :: Fixing Tags Complete!"		
	else
		log "$1 :: ERROR :: Unable to match using beets to a musicbrainz release..."
	fi	

	if [ -f "/config/extended/beets-postprocessor-match" ]; then 
		rm "/config/extended/beets-postprocessor-match"
		sleep 0.5
	fi

	if [ -f /config/extended/library-postprocessor.blb ]; then
		rm /config/extended/library-postprocessor.blb
		sleep 0.5
	fi
	if [ -f /config/extended/logs/beets.log ]; then 
		rm /config/extended/logs/beets.log
		sleep 0.5
	fi

	duration=$SECONDS
	log "$1 :: Finished in $(($duration / 60 )) minutes and $(($duration % 60 )) seconds!"
}

MetadataPostProcess () {
	# Process item with PlexNotify.bash if plexToken is configured
	log "Using MetadataPostProcess.bash to extract embedded lyrics & artwork...."
	bash /config/extended/MetadataPostProcess.bash "$1"

}

NotifyPlex () {
	# Process item with PlexNotify.bash if plexToken is configured
	if [ ! -z "$plexToken" ]; then
		# update plex
		log "$1 :: Using PlexNotify.bash to update Plex...."
		bash /config/extended/PlexNotify.bash "$2"
	fi
}

ProcessWithBeets "$getFolderPath"
MetadataPostProcess "$lidarr_album_id"
NotifyPlex "$getAlbumArtist" "$getAlbumArtistPath"
exit

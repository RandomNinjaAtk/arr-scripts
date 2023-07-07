#!/usr/bin/with-contenv bash
export LC_ALL=C.UTF-8
export LANG=C.UTF-8
TITLESHORT="VPP"
scriptVersion=1.0.0

set -e
set -o pipefail


InstallRequirements () {
  if [ ! -f "/config/logs/video.txt" ]; then
    echo "Installing Required Packages..."
    apk add -U --update --no-cache curl jq python3-dev py3-pip &>/dev/null
    pip install --upgrade --no-cache-dir -U yq &>/dev/null
    echo "Done"
  fi
  if [ ! -f /usr/local/sma/manual.py ]; then
    echo "************ setup SMA ************"
  	echo "************ setup directory ************"
  	mkdir -p /usr/local/sma
  	echo "************ download repo ************"
  	git clone https://github.com/mdhiggins/sickbeard_mp4_automator.git /usr/local/sma
  	mkdir -p /usr/local/sma/config && \
  	echo "************ create logging file ************"
  	mkdir -p /usr/local/sma/config && \
  	touch /usr/local/sma/config/sma.log && \
  	chgrp users /usr/local/sma/config/sma.log && \
  	chmod g+w /usr/local/sma/config/sma.log && \
  	echo "************ install pip dependencies ************" && \
  	python3 -m pip install --upgrade pip && \	
   	pip3 install -r /usr/local/sma/setup/requirements.txt
  fi
}


touch "/config/logs/video.txt"
chmod 666 "/config/logs/video.txt"
exec &> >(tee -a "/config/logs/video.txt")

function Configuration {
	log "SABnzbd Job: $jobname"
	log "SABnzbd Category: $category"
	log "DOCKER: $TITLE"
	log "SCRIPT VERSION: $scriptVersion"
	log "SCRIPT: Video Post Processor ($TITLESHORT)"
	log "CONFIGURATION VERIFICATION"
	log "##########################"
	
	log "Preferred Audio/Subtitle Languages: ${VIDEO_LANG}"
	if [ "${RequireLanguage}" = "true" ]; then
		log "Require Matching Language :: Enabled"
	else
		log "Require Matching Language :: Disabled"
	fi
	
	if [ ${VIDEO_SMA} = TRUE ]; then
		log "$TITLESHORT: Sickbeard MP4 Automator (SMA): ENABLED"
		if [ ${VIDEO_SMA_TAGGING} = TRUE ]; then
			tagging="-a"
			log "Sickbeard MP4 Automator (SMA): Tagging: ENABLED"
		else
			tagging="-nt"
			log "Sickbeard MP4 Automator (SMA): Tagging: DISABLED"
		fi
	else
		log "Sickbeard MP4 Automator (SMA): DISABLED"
	fi
	
	if [ -z "VIDEO_SMA_TAGGING" ]; then
		VIDEO_SMA_TAGGING=FALSE
	fi
}


function log {
    m_time=`date "+%F %T"`
    echo $m_time" :: $scriptVersion :: "$1
}

VideoLanguageCheck () {

	count=0
	fileCount=$(find "$1" -type f -regex ".*/.*\.\(m4v\|wmv\|mkv\|mp4\|avi\)" | wc -l)
	log "Processing ${fileCount} video files..."
	find "$1" -type f -regex ".*/.*\.\(m4v\|wmv\|mkv\|mp4\|avi\)" -print0 | while IFS= read -r -d '' file; do
		count=$(($count+1))
		baseFileName="${file%.*}"
		fileName="$(basename "$file")"
		extension="${fileName##*.}"
		log "$count of $fileCount :: Processing $fileName"
		videoData=$(ffprobe -v quiet -print_format json -show_streams "$file")
		videoAudioTracksCount=$(echo "${videoData}" | jq -r ".streams[] | select(.codec_type==\"audio\") | .index" | wc -l)
		videoSubtitleTracksCount=$(echo "${videoData}" | jq -r ".streams[] | select(.codec_type==\"subtitle\") | .index" | wc -l)
		log "$count of $fileCount :: $videoAudioTracksCount Audio Tracks Found!"
		log "$count of $fileCount :: $videoSubtitleTracksCount Subtitle Tracks Found!"
		videoAudioLanguages=$(echo "${videoData}" | jq -r ".streams[] | select(.codec_type==\"audio\") | .tags.language")
		videoSubtitleLanguages=$(echo "${videoData}" | jq -r ".streams[] | select(.codec_type==\"subtitle\") | .tags.language")

		# Language Check
		log "$count of $fileCount :: Checking for preferred languages \"$VIDEO_LANG\""
		preferredLanguage=false
		IFS=',' read -r -a filters <<< "$VIDEO_LANG"
		for filter in "${filters[@]}"
		do
			videoAudioTracksLanguageCount=$(echo "${videoData}" | jq -r ".streams[] | select(.codec_type==\"audio\") | select(.tags.language==\"${filter}\") | .index" | wc -l)
			videoSubtitleTracksLanguageCount=$(echo "${videoData}" | jq -r ".streams[] | select(.codec_type==\"subtitle\") | select(.tags.language==\"${filter}\") | .index" | wc -l)
			log "$count of $fileCount :: $videoAudioTracksLanguageCount \"$filter\" Audio Tracks Found!"
			log "$count of $fileCount :: $videoSubtitleTracksLanguageCount \"$filter\" Subtitle Tracks Found!"			
			if [ "$preferredLanguage" == "false" ]; then
				if echo "$videoAudioLanguages" | grep -i "$filter" | read; then
					preferredLanguage=true
				elif echo "$videoSubtitleLanguages" | grep -i "$filter" | read; then
					preferredLanguage=true
				fi
			fi
		done

		if [ "$preferredLanguage" == "false" ]; then
			if [ ${VIDEO_SMA} = TRUE ]; then
				if [ "$smaProcessComplete" == "false" ]; then
					return
				fi
			fi
			if [ "$RequireLanguage" == "true" ]; then
				log "$count of $fileCount :: ERROR :: No matching languages found in $(($videoAudioTracksCount + $videoSubtitleTracksCount)) Audio/Subtitle tracks"
				log "$count of $fileCount :: ERROR :: Disable "
				rm "$file" && log "INFO: deleted: $fileName"
			fi
		fi

		
		
		log "$count of $fileCount :: Processing complete for: ${fileName}!"

	done

}

VideoFileCheck () {
	# check for video files
	if find "$1" -type f -regex ".*/.*\.\(m4v\|wmv\|mkv\|mp4\|avi\)" | read; then
		sleep 0.1
	else
		log "ERROR: No video files found for processing"
		exit 1
	fi
}

VideoSmaProcess (){
	count=0
	fileCount=$(find "$1" -type f -regex ".*/.*\.\(m4v\|wmv\|mkv\|mp4\|avi\)" | wc -l)
	log "Processing ${fileCount} video files..."
	find "$1" -type f -regex ".*/.*\.\(m4v\|wmv\|mkv\|mp4\|avi\)" -print0 | while IFS= read -r -d '' file; do
		count=$(($count+1))
		baseFileName="${file%.*}"
		fileName="$(basename "$file")"
		extension="${fileName##*.}"
		log "$count of $fileCount :: Processing $fileName"
		if [ -f "$file" ]; then	
			if [ -f /usr/local/sma/config/sma.log ]; then
				rm /usr/local/sma/config/sma.log
			fi
			log "$count of $fileCount :: Processing with SMA..."
			if [ -f "/config/$2-sma.ini" ]; then
			
			# Manual run of Sickbeard MP4 Automator
				if python3 /usr/local/sma/manual.py --config "/config/$2-sma.ini" -i "$file" $tagging; then
					log "$count of $fileCount :: Complete!"
				else
					log "$count of $fileCount :: ERROR :: SMA Processing Error"
					rm "$file" && log "INFO: deleted: $fileName"
				fi
			else
				log "$count of $fileCount :: ERROR :: SMA Processing Error"
				log "$count of $fileCount :: ERROR :: \"/config/$2-sma.ini\" configuration file is missing..."
				rm "$file" && log "INFO: deleted: $fileName"
			fi
		fi
	done
	smaProcessComplete="true"
}

function Main {
	SECONDS=0
	error=0
	folderpath="$1"
	jobname="$3"
	category="$5"
	smaProcessComplete="false"
	
	Configuration
	VideoFileCheck "$folderpath"
	VideoLanguageCheck "$folderpath"
	VideoFileCheck "$folderpath"
	if [ ${VIDEO_SMA} = TRUE ]; then
		VideoSmaProcess "$folderpath" "$category"
	fi
	VideoFileCheck "$folderpath"
	VideoLanguageCheck "$folderpath"	
	VideoFileCheck "$folderpath"

	duration=$SECONDS
	echo "Post Processing Completed in $(($duration / 60 )) minutes and $(($duration % 60 )) seconds!"
}

InstallRequirements
Main "$@" 

exit $?

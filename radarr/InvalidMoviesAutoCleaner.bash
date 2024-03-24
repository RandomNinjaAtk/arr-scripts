#!/usr/bin/env bash
scriptVersion="1.2"
scriptName="InvalidMoviesAutoCleaner"

#### Import Settings
source /config/extended.conf
#### Import Functions
source /config/extended/functions
#### Create Log File
logfileSetup
#### Check Arr App
getArrAppInfo
verifyApiAccess

verifyConfig () {

  if [ "$enableInvalidMoviesAutoCleaner" != "true" ]; then
	log "Script is not enabled, enable by setting enableInvalidMoviesAutoCleaner to \"true\" by modifying the \"/config/extended.conf\" config file..."
	log "Sleeping (infinity)"
	sleep infinity
  fi

  if [ -z "$invalidMoviesAutoCleanerScriptInterval" ]; then
    invalidMoviesAutoCleanerScriptInterval="1h"
  fi
}


InvalidMovieAutoCleanerProcess () {
  
    # Get invalid series tmdbid id's
    movieTmdbid="$(curl -s --header "X-Api-Key:"$arrApiKey --request GET  "$arrUrl/api/v3/health" | jq -r '.[] | select(.source=="RemovedMovieCheck") | select(.type=="error")' | grep -o 'tmdbid [0-9]*' | grep -o '[[:digit:]]*')"
   
    if [ -z "$movieTmdbid" ]; then
        log "No invalid movies (tmdbid) reported by Radarr health check, skipping..."
        return
    fi

  
    # Process each invalid series tmdb id
    moviesData="$(curl -s --header "X-Api-Key:"$arrApiKey --request GET  "$arrUrl/api/v3/movie")"
    for tmdbid in $(echo $movieTmdbid); do
        movieData="$(echo "$moviesData" | jq -r ".[] | select(.tmdbId==$tmdbid)")"
        movieId="$(echo "$movieData" | jq -r .id)"
        movieTitle="$(echo "$movieData" | jq -r .title)"
        moviePath="$(echo "$movieData" | jq -r .path)"
        notifyPlex="false"
        if [ -d "$moviePath" ]; then
            notifyPlex="true"
        else
            notifyPlex="false"
        fi
      
        log "$movieId :: $movieTitle :: $moviePath :: Removing and deleting invalid movie (tmdbid: $tmdbid) based on Radarr Health Check error..."
        # Send command to Sonarr to delete series and files
        arrCommand=$(curl -s --header "X-Api-Key:"$arrApiKey --request DELETE "$arrUrl/api/v3/movie/$movieId?deleteFiles=true")
      
  
        if [ "$notifyPlex" == "true" ]; then
            # trigger a plex scan to remove the deleted movie
            folderToScan="$(dirname "$moviePath")"      
            log "Using PlexNotify.bash to update Plex.... ($folderToScan)"
            bash /config/extended/PlexNotify.bash "$folderToScan" "true"
        fi
    done

}

for (( ; ; )); do
	let i++
	logfileSetup
 	log "Script starting..."
  	verifyConfig
	getArrAppInfo
	verifyApiAccess
	InvalidMovieAutoCleanerProcess
	log "Script sleeping for $invalidMoviesAutoCleanerScriptInterval..."
	sleep $invalidMoviesAutoCleanerScriptInterval
done

exit

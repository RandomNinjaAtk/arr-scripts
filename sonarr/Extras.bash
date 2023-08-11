#!/usr/bin/env bash
scriptVersion="1.9"
arrEventType="$sonarr_eventtype"
arrItemId=$sonarr_series_id
tmdbApiKey="3b7751e3179f796565d88fdb2fcdf426"
autoScan="false"
updatePlex="false"
ytdlpExtraOpts="--user-agent facebookexternalhit/1.1"
scriptName="Extras"


#### Import Settings
source /config/extended.conf
#### Import Functions
source /config/extended/functions
#### Create Log File
logfileSetup

if [ "$enableExtras" != "true" ]; then
	log "Script is not enabled, enable by setting enableExtras to \"true\" by modifying the \"/config/extended.conf\" config file..."
	log "Sleeping (infinity)"
	sleep infinity
fi

getArrAppInfo
verifyApiAccess

if [ ! -z "$1" ]; then
    arrItemId="$1"
    autoScan="true"
fi


if [ "$arrEventType" == "Test" ]; then
	log "Tested Successfully"
	exit 0	
fi


# Get series information
arrItemData=$(curl -s "$arrUrl/api/v3/series/$arrItemId?apikey=$arrApiKey")
itemTitle=$(echo "$arrItemData" | jq -r .title)
itemHasFile=$(echo "$arrItemData" | jq -r .hasFile)
itemPath="$(echo "$arrItemData" | jq -r ".path")"
imdbId="$(echo "$arrItemData" | jq -r ".imdbId")"
tmdbId=$(curl -s "https://api.themoviedb.org/3/find/$imdbId?api_key=$tmdbApiKey&external_source=imdb_id" | jq -r .tv_results[].id)

# Check if series folder path exists
if [ ! -d "$itemPath" ]; then
    log "$itemTitle :: ERROR: Item Path does not exist ($itemPath), Skipping..."
    exit
fi

DownloadExtras () {

    # Check for cookies file
    if [ -f /config/cookies.txt ]; then
        cookiesFile="/config/cookies.txt"
        log "$itemTitle :: Cookies File Found!"
    else
        log "$itemTitle :: Cookies File Not Found!"
        cookiesFile=""
    fi

    IFS=',' read -r -a filters <<< "$extrasLanguages"
    for filter in "${filters[@]}"
    do    
    	if [ "$useProxy" != "true" ]; then
            tmdbVideosListData=$(curl -s "https://api.themoviedb.org/3/tv/$tmdbId/videos?api_key=$tmdbApiKey&language=$filter" | jq -r '.results[] | select(.site=="YouTube")')
        else 
            tmdbVideosListData=$(curl -x $proxyUrl:$proxyPort --proxy-user $proxyUsername:$proxyPassword -s "https://api.themoviedb.org/3/tv/$tmdbId/videos?api_key=$tmdbApiKey&language=$filter" | jq -r '.results[] | select(.site=="YouTube")')
        fi
	
        log "$itemTitle :: Searching for \"$filter\" extras..."
        if [ "$extrasType" == "all" ]; then
            tmdbVideosListDataIds=$(echo "$tmdbVideosListData" | jq -r ".id")
            tmdbVideosListDataIdsCount=$(echo "$tmdbVideosListData" | jq -r ".id" | wc -l)
        else
            tmdbVideosListDataIds=$(echo "$tmdbVideosListData" | jq -r "select(.type==\"Trailer\") | .id")
            tmdbVideosListDataIdsCount=$(echo "$tmdbVideosListData" | jq -r "select(.type==\"Trailer\") | .id" | wc -l)
        fi
        if [ -z "$tmdbVideosListDataIds" ]; then
            log "$itemTitle :: None found..."
            continue
        fi

        if [ $tmdbVideosListDataIdsCount -le 0 ]; then
            log "$itemTitle :: No Extras Found, skipping..."
            exit
        fi

        log "$itemTitle :: $tmdbVideosListDataIdsCount Extras Found!"
        i=0
        for id in $(echo "$tmdbVideosListDataIds"); do
            i=$(( i + 1))
            tmdbExtraData="$(echo "$tmdbVideosListData" | jq -r "select(.id==\"$id\")")"
            tmdbExtraTitle="$(echo "$tmdbExtraData" | jq -r .name)"
            tmdbExtraTitleClean="$(echo "$tmdbExtraTitle" | sed -e "s/[^[:alpha:][:digit:]$^&_+=()'%;{},.@#]/ /g" -e "s/  */ /g" | sed 's/^[.]*//' | sed  's/[.]*$//g' | sed  's/^ *//g' | sed 's/ *$//g')"
            tmdbExtraKey="$(echo "$tmdbExtraData" | jq -r .key)"
            tmdbExtraType="$(echo "$tmdbExtraData" | jq -r .type)"
            tmdbExtraOfficial="$(echo "$tmdbExtraData" | jq -r .official)"

            if [ "$tmdbExtraOfficial" != "true" ]; then
                if [ "$extrasOfficialOnly" == "true" ]; then
                    log "$itemTitle :: $i of $tmdbVideosListDataIdsCount :: $tmdbExtraType :: Not official, skipping..."
                    continue
                fi
            fi

            if [ "$tmdbExtraType" == "Featurette" ]; then
                extraFolderName="featurettes"
            elif [ "$tmdbExtraType" == "Trailer" ]; then
                extraFolderName="trailers"
            elif [ "$tmdbExtraType" == "Behind the Scenes" ]; then
                extraFolderName="behind the scenes"
            else
                extraFolderName="other"
            fi

            if [ ! -d "$itemPath/$extraFolderName" ]; then
                mkdir -p "$itemPath/$extraFolderName"
                chmod 777 "$itemPath/$extraFolderName"
            fi

            finalPath="$itemPath/$extraFolderName"
	    if [ "$extraFolderName" == "other" ]; then
     		finalFileName="$tmdbExtraTitleClean ($tmdbExtraType)"
     	    else
            	finalFileName="$tmdbExtraTitleClean"
	    fi

            if [ -f "$finalPath/$finalFileName.mkv" ]; then
                log "$itemTitle :: $i of $tmdbVideosListDataIdsCount :: $tmdbExtraType :: $tmdbExtraTitle ($tmdbExtraKey) :: Already Downloaded, skipping..."
                continue
            fi

            videoLanguages="$(echo "$extrasLanguages" | sed "s/-[[:alpha:]][[:alpha:]]//g")"

            log "$itemTitle :: $i of $tmdbVideosListDataIdsCount :: $tmdbExtraType :: $tmdbExtraTitle ($tmdbExtraKey) :: Downloading (yt-dlp :: $videoFormat)..."
            if [ ! -z "$cookiesFile" ]; then
                yt-dlp -f "$videoFormat" --no-video-multistreams --cookies "$cookiesFile" -o "$finalPath/$finalFileName" --write-sub --sub-lang $videoLanguages --embed-subs --merge-output-format mkv --no-mtime --geo-bypass $ytdlpExtraOpts "https://www.youtube.com/watch?v=$tmdbExtraKey"  2>&1 | tee -a /config/logs/$scriptName.txt
            else
                yt-dlp -f "$videoFormat" --no-video-multistreams -o "$finalPath/$finalFileName" --write-sub --sub-lang $videoLanguages --embed-subs --merge-output-format mkv --no-mtime --geo-bypass $ytdlpExtraOpts "https://www.youtube.com/watch?v=$tmdbExtraKey"  2>&1 | tee -a /config/logs/$scriptName.txt
            fi
            if [ -f "$finalPath/$finalFileName.mkv" ]; then
                log "$itemTitle :: $i of $tmdbVideosListDataIdsCount :: $tmdbExtraType :: $tmdbExtraTitle ($tmdbExtraKey) :: Compete"
                chmod 666 "$finalPath/$finalFileName.mkv"
            else
                log "$itemTitle :: $i of $tmdbVideosListDataIdsCount :: $tmdbExtraType :: $tmdbExtraTitle ($tmdbExtraKey) :: ERROR :: Download Failed"
                continue
            fi

            if python3 /config/extended/sma/manual.py --config "/config/extended/sma.ini" -i "$finalPath/$finalFileName.mkv" -nt; then
                log "$itemTitle :: $i of $tmdbVideosListDataIdsCount :: $tmdbExtraType :: $tmdbExtraTitle :: Processed with SMA..."
                rm  /config/extended/sma/config/*log*
            else
                log "$itemTitle :: $i of $tmdbVideosListDataIdsCount :: $tmdbExtraType :: $tmdbExtraTitle :: ERROR :: SMA Processing Error"
                rm "$finalPath/$finalFileName.mkv"
                log "$itemTitle :: $i of $tmdbVideosListDataIdsCount :: $tmdbExtraType :: $tmdbExtraTitle :: INFO: deleted: $finalPath/$finalFileName.mkv"
            fi
            updatePlex="true"
        done
    done

    # Mark Series Extras Complete
    if [ ! -d "/config/extended/logs/extras" ]; then 
        mkdir -p "/config/extended/logs/extras"
        chmod 777 "/config/extended/logs/extras"
    fi
    log "$itemTitle :: Marking/logging as Extras downloads complete (/config/extended/logs/extras/$tmdbId)"
    touch "/config/extended/logs/extras/$tmdbId"
    chmod 666 "/config/extended/logs/extras/$tmdbId"

}

NotifyPlex () {
    # Process item with PlexNotify.bash if plexToken is configured
    if [ ! -z "$plexToken" ]; then
        # Always update plex if extra is downloaded
        if [ "$updatePlex" == "true" ]; then
            log "$itemTitle :: Using PlexNotify.bash to update Plex...."
            bash /config/extended/PlexNotify.bash "$itemPath"
            exit
        fi
        
        # Do not notify plex if this script was triggered by the AutoExtras.bash and no Extras were downloaded
        if [ "$autoScan" == "true" ]; then 
            log "$itemTitle :: Skipping plex notification, not needed...."
            exit
        else
            log "$itemTitle :: Using PlexNotify.bash to update Plex...."
            bash /config/extended/PlexNotify.bash "$itemPath"
            exit
        fi
    fi
}

# Check if series has been previously processed
if [ -f "/config/extended/logs/extras/$tmdbId" ]; then
    # Delete log file older than 7 days, to allow re-processing
    find "/config/extended/logs/extras" -type f -mtime +7 -name "$tmdbId" -delete
fi

if [ -f "/config/extended/logs/extras/$tmdbId" ]; then
    log "$itemTitle :: Already processed Extras, waiting 7 days to re-check..."
    NotifyPlex
    exit
else
    DownloadExtras
    NotifyPlex
fi

exit

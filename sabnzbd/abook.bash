#!/usr/bin/with-contenv bash
scriptVersion="1.0"
scriptName="Audiobook Processor"
set -e
set -o pipefail
SECONDS=0
error=0
folderpath="$1"
jobname="$3"
category="$5"
downloadId="$SAB_NZO_ID"

log () {
  m_time=`date "+%F %T"`
  echo $m_time" :: $scriptName :: $scriptVersion :: "$1
}

log "Processing: $folderpath"

mainProcess () {
    log "Moving Files to "$folderpath/temp" directories for processing"
    for dir in "$folderpath"/*
    do
        if [ ! -d "$folderpath/temp" ]; then
            log "Creating \"$folderpath/temp\" directories"
            mkdir -p "$folderpath/temp/new"
            mkdir -p "$folderpath/temp/processed"
        fi
        mv "$dir" "$folderpath"/temp/new/
    done

    if [ -f /config/scripts/beets-books.log ]; then
    log "Removing beets log file: /config/scripts/beets-books.log"
    rm /config/scripts/beets-books.log
    fi

    log "Scanning with Beets: $folderpath/temp/new"
    beet -c /config/scripts/beets-books-config.yaml -l "$folderpath/library.blb" -d "$folderpath/temp/processed" import -q "$folderpath/temp/new"

    if [ -f /config/scripts/beets-books.log ]; then
    log "Removing beets log file: /config/scripts/beets-books.log"
    rm /config/scripts/beets-books.log
    fi

    if [ -f "$folderpath/library.blb" ]; then
    log "Removing beets library file: $folderpath/library.blb"
    rm "$folderpath/library.blb"
    fi

    if [ $(find "$folderpath/temp/processed" -type f -regex ".*/.*\.\(flac\|opus\|m4a\|m4b\|mp3\)" | wc -l) -gt 0 ]; then
        log "Beets audiobook match found"
        for dir in "$folderpath/temp/processed"/*
        do
            if [ ! -d "$folderpath/matched" ]; then
                log "Creating Directory: $folderpath/matched"
                mkdir -p "$folderpath/matched"
            fi
            log "Moving Beets matched files to: $folderpath/matched"
            mv "$dir" "$folderpath"/matched/
        done
    else
        log "Unable to match audiobook"
        for dir in "$folderpath/temp/new"/*
        do
            if [ ! -d "$folderpath/unmatched" ]; then
                log "Creating Directory: $folderpath/unmatched"
                mkdir -p "$folderpath/unmatched"
            fi
            log "Moving Beets unmatched files to: $folderpath/unmatched"
            mv "$dir" "$folderpath"/unmatched/
        done
    fi

    if [ -d "$folderpath/temp" ]; then
        log "Performing Cleanup"
        rm -rf "$folderpath/temp"/*
        rm -rf "$folderpath/temp"
    fi

    chmod 777 -R "$folderpath"/*

}

autoM4Bprocess () {

    log "Converting book to single chaptered m4b file..."

    if [ -d "/data/auto-m4b/untagged" ]; then
        rm -rf "/data/auto-m4b/untagged"/*
    fi

    for dir in "$folderpath/matched"/*
    do
        mv "$dir" /data/auto-m4b/recentlyadded/
    done
    if [ -d "$folderpath/matched" ]; then
        rm -rf "$folderpath/matched"
    fi

    if [ -d "/data/auto-m4b/untagged" ]; then
        rm -rf "/data/auto-m4b/untagged"/*
    fi

    alerted=no
    until false
    do
        if [ $(find "/data/auto-m4b/untagged" -type f -name "*.m4b" | wc -l) -eq 1 ]; then
            break
        else
            if [ "$alerted" == "no" ]; then
                alerted="yes"
                log "Waiting for auto-m4b process to complete, processing..."
            fi
            sleep 5
        fi
    done
    
    log "Moving untagged book to reprocess tags"
    for dir in "/data/auto-m4b/untagged"/*
    do
        mv "$dir" "$folderpath"/
    done

    if [ -d "/data/auto-m4b/untagged" ]; then
        rm -rf "/data/auto-m4b/untagged"/*
    fi
}

importIntoLibrary () {
    log "Importing Audiobook into library..."
    beet -c "/data/media/audiobooks/config.yaml" -l "/data/media/audiobooks/library.blb" -d "/data/media/audiobooks/authors" import -q "$folderpath/matched"
    log "Performing Cleanup"
    if [ -d "$folderpath" ]; then 
        rm -rf "$folderpath"/*
        rm -rf "$folderpath"
    fi
}

mainProcess
if [ -d "$folderpath/matched" ]; then
    if [ $(find "$folderpath/matched" -type f -regex ".*/.*\.\(flac\|opus\|m4a\|mp3\)" | wc -l) -gt 1 ]; then
        autoM4Bprocess
        mainProcess
    fi
fi

if [ -d "$folderpath/matched" ]; then
  if [ $(find "$folderpath/matched" -type f -regex ".*/.*\.\(flac\|opus\|m4a\|m4b\|mp3\)" | wc -l) -gt 0 ]; then
    importIntoLibrary
  fi
fi

duration=$SECONDS
echo "Post Processing Completed in $(($duration / 60 )) minutes and $(($duration % 60 )) seconds!"
exit

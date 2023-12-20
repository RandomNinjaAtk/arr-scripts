#!/usr/bin/env bash
scriptVersion=1.0
rootFolderPath="$(dirname "$readarr_author_path")"
scriptName="M4bCombine"


log() {
    m_time=$(date "+%F %T")
    echo "$m_time :: $scriptName :: $scriptVersion :: $1" >> "/config/logs/$scriptName-$(date +"%Y_%m_%d_%I_%M_%p").txt"
}

# Combine M4b Files
combineM4bFiles() {
    log "Combining M4b files using FFmpeg..."

    # Determine the M4b files path based on the context
    if [ -z "$readarr_author_path" ]; then
        # Extended script context
        m4bFiles="$readarr_artist_path/*.mp3 $readarr_artist_path/*.m4b"
        outputFolder="$readarr_artist_path/"
    else
        # Readarr context
        m4bFiles="$1/*.mp3 $1/*.m4b"
        outputFolder="$1/"
    fi

    # Extract author and book information
    author=$(basename "$(dirname "$readarr_author_path")")
    book=$(basename "$readarr_author_path")

    # Create the output file path
    outputFile="${outputFolder}${author}_${book}_combined.m4b"

    # FFmpeg command to concatenate M4b files
    ffmpeg -i "concat:$m4bFiles" -vn -b:a 128k -f m4b "$outputFile" 2>&1

    if [ $? -eq 0 ]; then
        log "M4b files combined successfully. Output: $outputFile"
        rm -f "$readarr_artist_path/*.mp3"
        log "MP3 files removed after successful M4b file combination."
    else
        log "Error combining M4b files with FFmpeg."
        log "original file untouched"
    fi
}

# Call the function to combine M4b files
combineM4bFiles "$readarr_artist_path"

exit 0

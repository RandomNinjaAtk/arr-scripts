# README

## Requirements

Container: <https://docs.linuxserver.io/images/docker-sonarr>  
Version Tag: develop (v4 is required for some of the features)

## Installation/setup

1. Add 2 volumes to your container
  `/custom-services.d` and `/custom-cont-init.d` (do not map to the same local folder...)
  Docker Run Example:
  `-v /path/to/preferred/local/folder-01:/custom-services.d`
  `-v /path/to/preferred/local/folder-02:/custom-cont-init.d`
1. Download the [script_init.bash](https://github.com/RandomNinjaAtk/arr-scripts/blob/main/sonarr/scripts_init.bash) ([Download Link](https://raw.githubusercontent.com/RandomNinjaAtk/arr-scripts/main/sonarr/scripts_init.bash)) and place it into the following folder: `/custom-cont-init.d`
1. Start your container and wait for the application to load
1. Optional: Customize the configuration by modifying the following file `/config/extended.conf`
1. Restart the container

## Updating

Updating is a bit more combersum. To update, do the following:

1. Download/update your local `/config/extended.conf` file with the latest options from: [extended.conf](https://github.com/RandomNinjaAtk/arr-scripts/blob/main/sonarr/extended.conf)
2. Restart the container, wait for it to fully load the application.
3. Restart the container again, for the new scripts to activate.

## Uninstallation/Removal  

1. Remove the 2 added volumes and delete the contents<br>
   `/custom-services.d` and `/custom-cont-init.d`
1. Delete the `/config/extended.conf` file
1. Delete the `/config/extended` folder and it's contents
1. Remove any Arr app customizations manually.

## Support
[Information](https://github.com/RandomNinjaAtk/arr-scripts/tree/main?tab=readme-ov-file#support-info)


## Features

<table>
  <tr>
    <td><img src="https://raw.githubusercontent.com/RandomNinjaAtk/unraid-templates/master/randomninjaatk/img/sonarr.png" width="200"></td>
    <td><img src="https://github.com/RandomNinjaAtk/docker-lidarr-extended/raw/main/.github/plus.png" width="100"></td>
    <td><img src="https://raw.githubusercontent.com/RandomNinjaAtk/unraid-templates/master/randomninjaatk/img/amtd.png" width="200"></td>
  </tr>
 </table>

* Downloading TV **Trailers** and **Extras** using online sources for use in popular applications (Plex):
  * Connects to Sonarr to automatically download trailers for TV Series in your existing library
  * Downloads videos using yt-dlp automatically
  * Names videos correctly to match Plex naming convention
* Auto Configure Sonarr with optimized settings
  * Optimized file/folder naming (based on trash guides)
  * Configures media management settings
  * Configures metadata settings
* Daily Series Episode Trimmer
  * Keep only the latest 14 episodes of a daily series
* Recyclarr built-in
  * Auto configures Release Profiles + Scores
  * Auto configures optimized quality definitions
* Plex Notify Script
  * Reduce Plex scanning by notifying Plex the exact folder to scan
* Queue Cleaner Script
  * Automatically removes downloads that have a "warning" or "failed" status that will not auto-import into Sonarr, which enables Sonarr to automatically re-search for the Title
* Youtube Series Downloader Script
  * Automatically downloads and imports episodes from Youtube.com for Sonarr series that have their network set as "Youtube"

For more details, visit the [Wiki](https://github.com/RandomNinjaAtk/arr-scripts/wiki)

### Plex Example

![amvtd](https://raw.githubusercontent.com/RandomNinjaAtk/docker-amtd/master/.github/amvtd-plex-example.jpg)

## Credits

* [ffmpeg](https://ffmpeg.org/)

* [yt-dlp](https://github.com/yt-dlp/yt-dlp)
* [linuxserver/sonarr](https://github.com/linuxserver/docker-sonarr) Base docker image
* [Sonarr](https://sonarr.tv/)
* [The Movie Database](https://www.themoviedb.org/)
* [Recyclarr](https://github.com/recyclarr/recyclarr)
* Icons made by [Freepik](https://www.freepik.com/) from [Flaticon](https://www.flaticon.com)

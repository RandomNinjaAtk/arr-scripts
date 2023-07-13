# Requirements
Container: https://docs.linuxserver.io/images/docker-sonarr<br>
Version Tag: develop (only if migrating from original sonarr-extended container...)

# Installation/setup
1. Add 2 volumes to your container <br>
  `/custom-services.d` and `/custom-cont-init.d` <br>
  Docker Run Example: <br>
  `-v /path/to/preferred/local/directory:/custom-services.d` <br>
  `-v /path/to/preferred/local/directory:/custom-cont-init.d`
3. Download the [script_init.bash](https://github.com/RandomNinjaAtk/arr-scripts/blob/main/sonarr/scripts_init.bash) and place it into the following folder: `/custom-cont-init.d`
4. Start your container and wait for the application to load
5. Optional: Customize the configuration by modifying the following file `/config/extended.conf`
6. Restart the container

# Updating
Updating is a bit more combersum. To update, do the following:
1. Download/update your local `/config/extended.conf` file with the latest options from: [extended.conf](https://github.com/RandomNinjaAtk/arr-scripts/blob/main/sonarr/extended.conf)
2. Restart the container, wait for it to fully load the application.
3. Restart the container again, for the new scripts to activate.

# Features
<table>
  <tr>
    <td><img src="https://raw.githubusercontent.com/RandomNinjaAtk/unraid-templates/master/randomninjaatk/img/sonarr.png" width="200"></td>
    <td><img src="https://github.com/RandomNinjaAtk/docker-lidarr-extended/raw/main/.github/plus.png" width="100"></td>
    <td><img src="https://raw.githubusercontent.com/RandomNinjaAtk/unraid-templates/master/randomninjaatk/img/amtd.png" width="200"></td>
  </tr>
 </table>
 
* [Downloading TV **Trailers** and **Extras** using online sources for use in popular applications (Plex):](https://github.com/RandomNinjaAtk/docker-sonarr-extended/wiki/Extras.bash) 
  * Connects to Sonarr to automatically download trailers for TV Series in your existing library
  * Downloads videos using yt-dlp automatically
  * Names videos correctly to match Plex naming convention
* [Auto Configure Sonarr with optimized settings](https://github.com/RandomNinjaAtk/docker-sonarr-extended/wiki/AutoConfig.bash)
  * Optimized file/folder naming (based on trash guides)
  * Configures media management settings
  * Configures metadata settings
* [Daily Series Episode Trimmer](https://github.com/RandomNinjaAtk/docker-sonarr-extended/wiki/DailySeriesEpisodeTrimmer.bash)
  * Keep only the latest 14 episodes of a daily series
* [Recyclarr built-in](https://github.com/RandomNinjaAtk/docker-sonarr-extended/wiki/Recyclarr.bash)
  * Auto configures Release Profiles + Scores
  * Auto configures optimzed quality definitions
* [Plex Notify Script](https://github.com/RandomNinjaAtk/docker-sonarr-extended/wiki/PlexNotify.bash)
  * Reduce Plex scanning by notifying Plex the exact folder to scan
* [Queue Cleaner Script](https://github.com/RandomNinjaAtk/docker-sonarr-extended/wiki/QueueCleaner.bash)
  * Automatically removes downloads that have a "warning" or "failed" status that will not auto-import into Sonarr, which enables Sonarr to automatically re-search for the Title
* [Youtube Series Downloader Script](https://github.com/RandomNinjaAtk/docker-sonarr-extended/wiki/Youtube-Series-Downloader.bash)
  * Automatically downloads and imports episodes from Youtube.com for Sonarr series that have their network set as "Youtube"

### Plex Example
![](https://raw.githubusercontent.com/RandomNinjaAtk/docker-amtd/master/.github/amvtd-plex-example.jpg)

 # Credits
- [ffmpeg](https://ffmpeg.org/)
- [yt-dlp](https://github.com/yt-dlp/yt-dlp)
- [linuxserver/sonarr](https://github.com/linuxserver/docker-sonarr) Base docker image
- [Sonarr](https://sonarr.tv/)
- [The Movie Database](https://www.themoviedb.org/)
- [Recyclarr](https://github.com/recyclarr/recyclarr)
- Icons made by <a href="http://www.freepik.com/" title="Freepik">Freepik</a> from <a href="https://www.flaticon.com/" title="Flaticon"> www.flaticon.com</a>

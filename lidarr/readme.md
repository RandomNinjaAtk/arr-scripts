  # Requirements
Container: https://docs.linuxserver.io/images/docker-lidarr<br>

# Installation/setup
1. Add 2 volumes to your container <br>
  `/custom-services.d` and `/custom-cont-init.d` <br>
  Docker Run Example: <br>
  `-v /path/to/preferred/local/directory:/custom-services.d` <br>
  `-v /path/to/preferred/local/directory:/custom-cont-init.d`
3. Download the [script_init.bash](https://github.com/RandomNinjaAtk/arr-scripts/blob/main/lidarr/scripts_init.bash) and place it into the following folder: `/custom-cont-init.d`
4. Start your container and wait for the application to load
5. Optional: Customize the configuration by modifying the following file `/config/extended.conf`
6. Restart the container

# Credits
- [LinuxServer.io Team](https://github.com/linuxserver/docker-lidarr)
- [Lidarr](https://lidarr.audio/)
- [Beets](https://beets.io/)
- [Deemix download client](https://deemix.app/)
- [Tidal-Media-Downloader client](https://github.com/yaronzz/Tidal-Media-Downloader)
- [r128gain](https://github.com/desbma/r128gain)
- [Algorithm Implementation/Strings/Levenshtein distance](https://en.wikibooks.org/wiki/Algorithm_Implementation/Strings/Levenshtein_distance)
- [ffmpeg](https://ffmpeg.org/)
- [yt-dlp](https://github.com/yt-dlp/yt-dlp)
- [SMA Conversion/Tagging Automation Script](https://github.com/mdhiggins/sickbeard_mp4_automator)
- [Freyr](https://github.com/miraclx/freyr-js)

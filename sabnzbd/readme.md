# Requirements
Container: [https://docs.linuxserver.io/images/docker-sonarr](https://docs.linuxserver.io/images/docker-sabnzbd)<br>

# Installation/setup
1. Add volume to your container <br>
  `/custom-cont-init.d` <br>
  Docker Run Example: <br>
  `-v /path/to/preferred/local/directory:/custom-cont-init.d`
3. Download the [script_init.bash](https://github.com/RandomNinjaAtk/arr-scripts/blob/main/sabnzbd/scripts_init.bash) and place it into the following folder: `/custom-cont-init.d`
4. Start your container and wait for the application to load
5. Optional: Customize the configuration by modifying the following file `/config/extended.conf`
6. Restart the container
7. Add the `/config/scripts` folder to the "Scripts Folder" folder setting in SABnzbd
8. Add `video.bash` or `audio.bash` script to the appropriate SABnzbd category 

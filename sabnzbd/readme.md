# Requirements
Container: [https://docs.linuxserver.io/images/docker-sabnzbd](https://docs.linuxserver.io/images/docker-sabnzbd)<br>

# Installation/setup
1. Add volume to your container <br>
  `/custom-cont-init.d` <br>
  Docker Run Example: <br>
  `-v /path/to/preferred/local/directory:/custom-cont-init.d`
1. Download the [script_init.bash](https://github.com/RandomNinjaAtk/arr-scripts/blob/main/sabnzbd/scripts_init.bash) and place it into the following folder: `/custom-cont-init.d`
1. Start your container and wait for the application to load
1. Optional: Customize the configuration by modifying the following file `/config/extended.conf`
1. Add the `/config/scripts` folder to the "Scripts Folder" folder setting in SABnzbd
1. Add `video.bash` or `audio.bash` script to the appropriate SABnzbd category 

# Updating
Updating is a bit more combersum. To update, do the following:
1. Download/update your local `/config/extended.conf` file with the latest options from: [extended.conf](https://github.com/RandomNinjaAtk/arr-scripts/blob/main/sabnzbd/extended.conf)
2. Restart the container, wait for it to fully load the application.
3. Restart the container again, for the new scripts to activate.

# Additional Information
For more details, visit the [Wiki](https://github.com/RandomNinjaAtk/arr-scripts/wiki)

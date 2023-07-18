# Readarr
## Requirements
Container: https://hub.docker.com/r/linuxserver/readarr<br>

## Installation/setup
1. Add 2 volumes to your container <br>
  `/custom-services.d` and `/custom-cont-init.d` (do not map to the same local folder...) <br> 
  Docker Run Example: <br>
  `-v /path/to/preferred/local/folder-01:/custom-services.d` <br>
  `-v /path/to/preferred/local/folder-02:/custom-cont-init.d`
3. Download the [script_init.bash](https://github.com/RandomNinjaAtk/arr-scripts/blob/main/readarr/scripts_init.bash) and place it into the following folder: `/custom-cont-init.d`
4. Start your container and wait for the application to load
5. Optional: Customize the configuration by modifying the following file `/config/extended.conf`
6. Restart the container

# Updating
Updating is a bit more combersum. To update, do the following:
1. Download/update your local `/config/extended.conf` file with the latest options from: [extended.conf](https://github.com/RandomNinjaAtk/arr-scripts/blob/main/readarr/extended.conf)
2. Restart the container, wait for it to fully load the application.
3. Restart the container again, for the new scripts to activate.

This configuration does its best to update everything automatically, but with how the core system is designed, the new scripts will not take affect until a second restart is completed because the container copies/uses the previous versions of the script for execution on the first restart.

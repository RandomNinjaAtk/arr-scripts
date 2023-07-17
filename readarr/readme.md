# Readarr (Untested... should work...)
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

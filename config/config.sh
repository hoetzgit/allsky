#!/bin/bash

# CAMERA is no longer set here - set it in the WebUI.
# It's an advanced option so you need to click on the "Show Advanced Options" button.


########## Images
# Set to "true" to upload the current image to your website.
IMG_UPLOAD="true"

# If IMG_UPLOAD is "true", upload images every IMG_UPLOAD_FREQUENCY frames, e.g., every 5 frames.
# 1 uploades every frame.
IMG_UPLOAD_FREQUENCY=1

# The websites look in IMG_DIR for the current image.
# When using the Allsky website from the "allsky-website" package,
# "current" is an alias for "/home/pi/allsky".
# If you use the default IMG_DIR and have the Allsky website, set "imageName" in
# /var/www/html/allsky/config.js to:
#     imageName: "/current/tmp/image.jpg",
# This avoids copying the image to the website.
# Only change IMG_DIR if you know what you are doing.
IMG_DIR="current/tmp"

# Resize images before cropping, stretching, and saving.
# Adjust IMG_WIDTH and IMG_HEIGHT according to your camera's sensor ratio.
# The numbers below are only examples.
IMG_RESIZE="false"
IMG_WIDTH=2028
IMG_HEIGHT=1520

# Crop images before stretching and saving.
# This is useful to remove some of the black border when using a fisheye lens.
# If you crop an image you may need to change the "Text X" and/or "Text Y" settings in the WebUI.
# The numbers below are only examples.
CROP_IMAGE="false"
CROP_WIDTH=640
CROP_HEIGHT=480
CROP_OFFSET_X=0
CROP_OFFSET_Y=0

# Auto stretch images saved at night.
# The numbers below are good defaults.
AUTO_STRETCH="false"
AUTO_STRETCH_AMOUNT=10
AUTO_STRETCH_MID_POINT="10%"

# Resize uploaded images.  Change the size to fit your sensor.  
# The numbers below are only examples.
RESIZE_UPLOADS="true"
RESIZE_UPLOADS_SIZE="962x720"

# Create thumbnails of images.  If you never look at them, consider changing this to "false".
IMG_CREATE_THUMBNAILS="false"

# Remove corrupt images before generating keograms, startrails, and timelapse videos.
# We recommend ALWAYS leaving this enabled.
# If the software is deleting images you want to keep, change the settings below.
REMOVE_BAD_IMAGES="false"

# If REMOVE_BAD_IMAGES is "true", images whose mean brightness is
# less than THRESHOLD_LOW or greater than THRESHOLD_HIGH percent (max: 100) will be removed.
# Set either variable to 0 to disable its brightness check.
# The numbers below are good defaults.
REMOVE_BAD_IMAGES_THRESHOLD_LOW=1
REMOVE_BAD_IMAGES_THRESHOLD_HIGH=90

# Additional Capture parameters.  Run either "capture --help" or "capture_RPiHQ -help" to see the options,
# depending on what camera you have (ZWO or RPiHQ).
CAPTURE_EXTRA_PARAMETERS=""


########## Timelapse
# Set to "true" to generate a timelapse video at the end of each night.
TIMELAPSE="true"

# Set the resolution of the timelapse video (sizes must be EVEN numbers).
# 0 disables resize and uses the same resolution as the images.
TIMELAPSEWIDTH=1440
TIMELAPSEHEIGHT=1080

# Bitrate of the timelapse video.  Higher numbers will produce higher quality but larger files.
TIMELAPSE_BITRATE="2000k"

# Timelapse video Frames Per Second.
FPS=12

# Encoder for timelapse video. May be changed to use a hardware encoder or different codec.
VCODEC="libx264"

# Pixel format.
PIX_FMT="${PIX_FMT:-yuv420p}"

# FFLOG determines the amount of log information displayed while creating a timelapse video.
# Set to "info" to see additional information if you are tuning the algorithm.
FFLOG="warning"

# While creating a timelapse video, a sequence of links to the images is created.
# Set to "true" to keep that sequence; set to "false" to have it deleted when done.
KEEP_SEQUENCE="false"

# Any additional timelapse parameters.  Run "ffmpeg -?" to see the options.
TIMELAPSE_EXTRA_PARAMETERS=""

# Set to "true" to upload the timelapse video to your website at the end of each night.
UPLOAD_VIDEO="true"

# Set to "true" to upload the timelapse video's thumbnail to your website at the end of each night.
# Not needed if the Allsky Website is on your Pi.
TIMELAPSE_UPLOAD_THUMBNAIL="false"

### Mini timelapse
# A "mini" timelapse is one that only includes the most recent images,
# is created often, and overwrites the prior mini video.
# TIMELAPSE_MINI_IMAGES is the number of images you want in the mini timelapse.
# 0 disables mini timelapses.
#TIMELAPSE_MINI_IMAGES=20
TIMELAPSE_MINI_IMAGES=0
# After how many images should the mini timelapse be made?
# If you have a slow Pi or short delays between images,
# set this to a higher number (i.e., not as often).
TIMELAPSE_MINI_FREQUENCY=5

# The remaining TIMELAPSE_MINI variables serve the same function as the daily timelapse.
#TIMELAPSE_MINI_UPLOAD_VIDEO="true"
TIMELAPSE_MINI_UPLOAD_VIDEO="false"
TIMELAPSE_MINI_UPLOAD_THUMBNAIL="false"

# Since a mini timelapse doesn't have many frames, the FPS should be much lower than a normal timelapse.
TIMELAPSE_MINI_FPS=2

# In order to decrease the time spent making mini timelapse, set these lower than a normal timelapse.
TIMELAPSE_MINI_BITRATE="1000k"
# The numbers below are only examples, but sizes must be EVEN numbers.
TIMELAPSE_MINI_WIDTH=1440
TIMELAPSE_MINI_HEIGHT=1080


########## Keogram
# Set to "true" to generate a keogram at the end of each night.
KEOGRAM="true"

# Additional Keogram parameters.  Run "keogram --help" to see the options.
KEOGRAM_EXTRA_PARAMETERS="--font-size 2.0 --font-line 2 --font-color '255 255 255' -x -c"

# Set to "true" to upload the keogram image to your website at the end of each night.
UPLOAD_KEOGRAM="true"


########## Startrails
# Set to "true" to generate a startrails image of each night.
STARTRAILS="true"

# Images with a brightness higher than this threshold will be skipped for
# startrails image generation.  Values are 0.0 to 1.0.
BRIGHTNESS_THRESHOLD=0.42
#0.42

# Any additional startrails parameters.  Run "startrails --help" to see the options.
STARTRAILS_EXTRA_PARAMETERS=""

# Set to "true" to upload the startrails image to your website at the end of each night.
UPLOAD_STARTRAILS="true"


########## Other
# Size of thumbnails.
THUMBNAIL_SIZE_X=100
THUMBNAIL_SIZE_Y=75

# Set this value to the number of days images plus videos you want to keep.
# Set to "" to keep ALL days.
DAYS_TO_KEEP=30

# Same as DAYS_TO_KEEP, but for the Allsky Website, if installed.
# Set to "" to keep ALL days.
WEB_DAYS_TO_KEEP=""

# Set to "true" to upload data to your server at the end of each night.
# This is needed if you are running the Allsky Website.
POST_END_OF_NIGHT_DATA="true"

# If you have additional data or buttons you want displayed on the WebUI's System page,
# see the WEBUI_DATA_FILES configuration variable in the "Software settings" section of
# https://github.com/thomasjacquin/allsky/wiki/allsky-Settings for details.
WEBUI_DATA_FILES="/home/pi/allsky/tmp/climate.txt"

# The uhubctl command can reset the USB bus if the camera isn't found and you know it's there.
# Allsky.sh uses this to try and fix "missing" cameras.
# Specify the path to the command and the USB bus number (on a Pi 4, bus 1 is USB 2.0 and
# bus 2 is the USB 3.0 ports).  If you don't have 'uhubctl' installed set UHUBCTL_PATH="".
UHUBCTL_PATH=""
UHUBCTL_PORT=2


# ================ DO NOT CHANGE ANYTHING BELOW THIS LINE ================
END_OF_USER_SETTINGS="true"		# During upgrades, stop looking for variables here.

CAMERA_TYPE="RPi"
if [ "${CAMERA_TYPE}" = "" ]; then
	echo -e "${RED}${ME}: ERROR: Please set 'Camera Type' in the WebUI.${NC}"
	sudo systemctl stop allsky > /dev/null 2>&1
	exit ${EXIT_ERROR_STOP}
fi

# This is needed in case the user changed the default location the current image is saved to.
if [ "${IMG_DIR}" = "current/tmp" ]; then
	CAPTURE_SAVE_DIR="${ALLSKY_TMP}"
else
	CAPTURE_SAVE_DIR="${IMG_DIR}"
fi

# Don't try to upload a mini timelapse if they aren't using them.
if [[ ${TIMELAPSE_MINI_IMAGES} -le 0 ]]; then
	TIMELAPSE_MINI_UPLOAD_VIDEO="false"
	TIMELAPSE_MINI_UPLOAD_THUMBNAIL="false"
fi

if [[ ! -f ${SETTINGS_FILE} ]]; then		# SETTINGS_FILE is defined in variables.sh
	echo -e "${RED}${ME}: ERROR: Settings file '${SETTINGS_FILE}' not found!${NC}"
	sudo systemctl stop allsky > /dev/null 2>&1
	exit ${EXIT_ERROR_STOP}
fi

# Simple way to get a setting that hides the details.
function settings()
{
	j="$(jq -r "${1}" "${SETTINGS_FILE}")" && echo "${j}" && return
	echo "${ME}: running as $(id --user --name), unable to get json value for '${1}';" >&2
	ls -l "${SETTINGS_FILE}" >&2
}

# Get the name of the file the websites will look for, and split into name and extension.
FULL_FILENAME="$(settings ".filename")"
EXTENSION="${FULL_FILENAME##*.}"
FILENAME="${FULL_FILENAME%.*}"
 
# So scripts can conditionally output messages.
ALLSKY_DEBUG_LEVEL="$(settings '.debuglevel')"
ALLSKY_VERSION="2022.10.19-mymods"	# Updated during installation

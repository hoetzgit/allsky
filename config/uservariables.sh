# Holds all the images without overlay on a per-day basis.
ALLSKY_IMAGES_CLEAN="${ALLSKY_IMAGES}/clean"

# Holds all the images wit compass overlay on a per-day basis.
ALLSKY_IMAGES_COMPASS="${ALLSKY_IMAGES}/compass"

# Location of optional allsky-website package.
ALLSKY_WEBSITE="/var/www/html/allsky-website"
ALLSKY_WEBSITE_CONFIGURATION_NAME="configuration.json"
ALLSKY_REMOTE_WEBSITE_CONFIGURATION_NAME="remote_${ALLSKY_WEBSITE_CONFIGURATION_NAME}"
ALLSKY_WEBSITE_CONFIGURATION_FILE="${ALLSKY_WEBSITE}/${ALLSKY_WEBSITE_CONFIGURATION_NAME}"
ALLSKY_REMOTE_WEBSITE_CONFIGURATION_FILE="${ALLSKY_CONFIG}/${ALLSKY_REMOTE_WEBSITE_CONFIGURATION_NAME}"

# Prefix saveImage.sh
# Example: saveImage.sh with task-spooler
# SAVEIMAGE_PREFIX="ts -n "
export SAVEIMAGE_PREFIX=""

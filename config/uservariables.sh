# Holds all the images without overlay on a per-day basis.
ALLSKY_IMAGES_CLEAN="${ALLSKY_IMAGES}/clean"

# Holds all the images wit compass overlay on a per-day basis.
ALLSKY_IMAGES_COMPASS="${ALLSKY_IMAGES}/compass"

# Location of optional allsky-website package.
ALLSKY_WEBSITE="/var/www/html/allsky-website"

# Prefix saveImage.sh
# Example: saveImage.sh with task-spooler
# SAVEIMAGE_PREFIX="ts -n "
export SAVEIMAGE_PREFIX=""

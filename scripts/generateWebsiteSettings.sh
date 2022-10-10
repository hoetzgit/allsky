#!/bin/bash

if [ -z "${ALLSKY_HOME}" ]
then
  export ALLSKY_HOME="/home/pi/allsky"
fi

# TODO check if ${ALLSKY_WEBSITE}/settings dir exists

source "${ALLSKY_HOME}/variables.sh"
sudo wget -q -O "${ALLSKY_WEBSITE}/settings/index.php" http://localhost/settings.php
sudo chown pi:www-data "${ALLSKY_WEBSITE}/settings/index.php"
exit 0

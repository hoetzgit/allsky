#!/bin/bash

ME="$(basename "${BASH_ARGV0}")"

# Allow this script to be executed manually, which requires several variables to be set.
if [ -z "${ALLSKY_HOME}" ] ; then
	ALLSKY_HOME="$(realpath "$(dirname "${BASH_ARGV0}")/..")"
	export ALLSKY_HOME
fi
# shellcheck disable=SC1090
source "${ALLSKY_HOME}/variables.sh"
# shellcheck disable=SC1090
source "${ALLSKY_CONFIG}/config.sh"
# shellcheck disable=SC1090
source "${ALLSKY_CONFIG}/ftp-settings.sh"

sudo systemctl stop allsky && ${ALLSKY_SCRIPTS}/copy_notification_image.sh Maintenance

#!/bin/bash

ME="$(basename "${BASH_ARGV0}")"

# Allow this script to be executed manually, which requires several variables to be set.
if [[ -z ${ALLSKY_HOME} ]]; then
	ALLSKY_HOME="$(realpath "$(dirname "${BASH_ARGV0}")/..")"
	export ALLSKY_HOME
fi
# shellcheck disable=SC1090
source "${ALLSKY_HOME}/variables.sh"
# shellcheck disable=SC1090
source "${ALLSKY_CONFIG}/config.sh"
# shellcheck disable=SC1090
source "${ALLSKY_CONFIG}/ftp-settings.sh"

if [ $# -eq 1 ] ; then
	if [[ ${1} = "-h" || ${1} = "--help" ]]; then
		echo -e "Usage: ${ME} [YYYYmmdd]"
		exit 0
	else
		DATE="${1}"
	fi
else
	DATE=$(date -d 'yesterday' +'%Y%m%d')
fi

DATE_DIR="${ALLSKY_IMAGES}/${DATE}"
if [[ ! -d ${DATE_DIR} ]]; then
	echo -e "${ME}: ${RED}ERROR: '${DATE_DIR}' not found!${NC}"
	exit 2
fi

# Post end of night data. This includes next twilight time
if [[ ${POST_END_OF_NIGHT_DATA} == "true" ]]; then
	echo -e "${ME}: ===== Posting twilight data"
	"${ALLSKY_SCRIPTS}/postData.sh"
fi

# Generate timelapse from collected images.
# Use generateForDay.sh instead of putting all the commands here so users can easily
# test the timelapse creation, which sometimes has issues.
if [[ ${TIMELAPSE} == "true" ]]; then
	echo -e "${ME}: ===== Generating Timelapse"
	"${ALLSKY_SCRIPTS}/generateForDay.sh" --silent -t ${DATE}
	RET=$?
	echo -e "${ME}: ===== Timelapse complete"
	if [[ ${UPLOAD_VIDEO} == "true" && ${RET} = 0 ]] ; then
		"${ALLSKY_SCRIPTS}/generateForDay.sh" --upload -t ${DATE}
	fi
fi

exit 0

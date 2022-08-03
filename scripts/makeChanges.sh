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


function usage_and_exit()
{
	echo -e "${wERROR}"
	echo "Usage: ${ME} [--debug] [--cameraTypeOnly] [--restarting] key label old_value new_value [...]"
	echo -e "${wNC}"
	echo "There must be a multiple of 4 key/label/old_value/new_value arguments."
	exit ${1}
}

# Check arguments
OK=true
DEBUG=false
HELP=false
RESTARTING=false			# Will the caller restart Allsky?
CAMERA_TYPE_ONLY=false		# Only update the cameraType ?

while [ $# -gt 0 ]; do
	ARG="${1}"
	case "${ARG}" in
		--debug)
			DEBUG="true"
			;;
		--help)
			HELP="true"
			;;
		--cameraTypeOnly)
			CAMERA_TYPE_ONLY="true"
			;;
		--restarting)
			RESTARTING="true"
			;;
		-*)
			echo -e "${wERROR}ERROR: Unknown argument: '${ARG}'${wNC}" >&2
			OK="false"
			;;
		*)
			break
			;;
	esac
	shift
done

[[ ${HELP} == "true" ]] && usage_and_exit 0
[[ ${OK} == "false" ]] && usage_and_exit 1
[[ $# -eq 0 ]] && usage_and_exit 1
[ $(($# % 4)) -ne 0 ] && usage_and_exit 2


# This output may go to a web page, so use "w" colors.
# shell check doesn't realize there were set in variables.sh
wOK="${wOK}"
wWARNING="${wWARNING}"
wERROR="${wERROR}"
wDEBUG="${wDEBUG}"
wBOLD="${wBOLD}"
wNBOLD="${wNBOLD}"
wNC="${wNC}"

# Does the change need Allsky to be restarted in order to take affect?
NEEDS_RESTART=false

RUN_POSTDATA=false
RUN_POSTTOMAP=false
POSTTOMAP_ACTION=""
WEBSITE_CONFIG=()

while [ $# -gt 0 ]; do
	KEY="${1}"
	LABEL="${2}"
	OLD_VALUE="${3}"
	NEW_VALUE="${4}"
	if [ "${DEBUG}" = "true" ]; then
		MSG="${KEY} old [${OLD_VALUE}], new [${NEW_VALUE}]"
		echo "${wDEBUG}${ME}: ${MSG}${wNC}"
		echo "<script>console.log('${MSG}');</script>"
	fi

	# Unfortunately, the Allsky configuration file was already updated,
	# so if we find a bad entry, e.g., a file doesn't exist, all we can do is warn the user.
	case "${KEY}" in

		cameraType)
			# If we can't set the new camera type, it's a major problem so exit right away.
			# When we're changing cameraType we're not changing anything else.

			# Create the camera capabilities file for the new camera type.
			CC_FILE="${ALLSKY_CONFIG}/${CC_FILE_NAME}.${CC_FILE_EXT}"

			# Save the current file just in case creating a new one fails.
			# It's a link so copy it to a temp name, then remove the old name.
			cp "${CC_FILE}" "${CC_FILE}-OLD"
			rm -f "${CC_FILE}"

			# Debug level 3 to give the user more info on error.
			"${ALLSKY_HOME}/capture_${NEW_VALUE}" -debuglevel 3 -cc_file "${CC_FILE}"
			RET=$?
			if [ ${RET} -ne 0 ]; then
				# Restore prior cc file.
				mv "${CC_FILE}-OLD" "${CC_FILE}"
				exit ${RET}		# the actual exit code is important
			fi

			# Create a link to a file that contains the camera type and model in the name.
			CAMERA_TYPE="${NEW_VALUE}"		# already know it
			CAMERA_MODEL="$(jq .cameraModel "${CC_FILE}" | sed 's;";;g')"
			# Get the filename (without extension) and extension of the cc file.

			LINKED_NAME="${ALLSKY_CONFIG}/${CC_FILE_NAME}_${CAMERA_TYPE}_${CAMERA_MODEL}.${CC_FILE_EXT}"
			# Any old and new camera capabilities file should be the same unless the
			# Allsky adds or changes capabilities, so delete the old one just in case.
			ln --force "${CC_FILE}" "${LINKED_NAME}"

			sed -i -e "s/^CAMERA_TYPE=.*$/CAMERA_TYPE=\"${NEW_VALUE}\"/" "${ALLSKY_CONFIG}/config.sh" >&2
			# shellcheck disable=SC2181
			if [ $? -ne 0 ]; then
				echo -e "${wERROR}ERROR updating ${wBOLD}${LABEL}${wNBOLD}.${wNC}" >&2
				mv "${CC_FILE}-OLD" "${CC_FILE}"
				exit 1
			fi

			# Remove the old file
			rm -f "${CC_FILE}-OLD"

			# createAllskyOptions.php will use the cc file and the options template file
			# to create an OPTIONS_FILE for this camera type/model.
			CC_FILE="${CC_FILE_NAME}.${CC_FILE_EXT}"		# reset from full name above
			OPTIONS_FILE="${OPTIONS_FILE_NAME}.${OPTIONS_FILE_EXT}"
			SETTINGS_FILE="${SETTINGS_FILE_NAME}.${SETTINGS_FILE_EXT}"

			# .php files don't return error codes so we check if it worked by
			# looking for a string in its output.
			R="$("${ALLSKY_WEBUI}/includes/createAllskyOptions.php" --dir "${ALLSKY_CONFIG}" --cc_file "${CC_FILE}" --options_file "${OPTIONS_FILE}" --settings_file "${SETTINGS_FILE}" 2>&1)"
			[ -n "${R}" ] && echo -e "${R}"
			echo -e "${R}" | grep --silent "XX_WORKED_XX" || exit 2

			# Don't do anything else if ${CAMERA_TYPE_ONLY} is set.
			[[ ${CAMERA_TYPE_ONLY} == "true" ]] && exit 0

			NEEDS_RESTART=true
			;;

		filename)
			WEBSITE_CONFIG+=("imageName" "${OLD_VALUE}" "${NEW_VALUE}")
			NEEDS_RESTART=true
			;;
		extratext)
			# It's possible the user will create/populate the file while Allsky is running,
			# so it's not an error if the file doesn't exist or is empty.
			if [ -n "${NEW_VALUE}" ]; then
				if [ ! -f "${NEW_VALUE}" ]; then
					echo -e "${wWARNING}WARNING: '${NEW_VALUE}' does not exist; please change it.${wNC}" >&2
				elif [ ! -s "${NEW_VALUE}" ]; then
					echo -e "${wWARNING}WARNING: '${NEW_VALUE}' is empty; please change it.${wNC}" >&2
				fi
			fi
			NEEDS_RESTART=true
			;;
		latitude | longitude)
			# Allow either +/- decimal numbers, OR numbers with N, S, E, W, but not both.
			NEW_VALUE="${NEW_VALUE^^[nsew]}"	# convert any character to uppercase for consistency
			SIGN="${NEW_VALUE:0:1}"				# First character, may be "-" or "+" or a number
			LAST="${NEW_VALUE: -1}"				# May be N, S, E, or W, or a number
			if [[ (${SIGN} = "+" || ${SIGN} == "-") && (${LAST%[NSEW]} == "") ]]; then
				echo -e "${wWARNING}WARNING: '${NEW_VALUE}' should contain EITHER a \"${SIGN}\" OR a \"${LAST}\", but not both; please change it.${wNC}" >&2
			else
				WEBSITE_CONFIG+=("${KEY}" "" "${NEW_VALUE}")
				RUN_POSTDATA=true
			fi
			NEEDS_RESTART=true
			;;
		angle)
			RUN_POSTDATA=true
			NEEDS_RESTART=true
			;;
		takeDaytimeImages)
			RUN_POSTDATA=true
			NEEDS_RESTART=true
			;;
		config)
			if [ "${NEW_VALUE}" = "" ]; then
				NEW_VALUE="[none]"
			elif [ "${NEW_VALUE}" != "[none]" ]; then
				if [ ! -f "${NEW_VALUE}" ]; then
					echo -e "${wWARNING}WARNING: Configuration File '${NEW_VALUE}' does not exist; please change it.${wNC}" >&2
				elif [ ! -s "${NEW_VALUE}" ]; then
					echo -e "${wWARNING}WARNING: Configuration File '${NEW_VALUE}' is empty; please change it.${wNC}" >&2
				fi
			fi
			;;
		showonmap)
			[ "${NEW_VALUE}" = "0" ] && POSTTOMAP_ACTION="--delete"
			RUN_POSTTOMAP=true
			;;
		location | owner | camera | lens | computer)
			RUN_POSTTOMAP=true
			WEBSITE_CONFIG+=("${KEY}" "" "${NEW_VALUE}")
			;;
		websiteurl | imageurl)
			RUN_POSTTOMAP=true
			;;

		*)
			echo -e "${wWARNING}WARNING: Unknown label '${LABEL}', key='${KEY}'; ignoring.${wNC}" >&2
			;;
		esac
		shift 4
done

if [[ ${RUN_POSTDATA} == "true" && ${POST_END_OF_NIGHT_DATA} == "true" ]]; then
	if RESULT="$("${ALLSKY_SCRIPTS}/postData.sh" >&2)" ; then
		echo -en "${wOK}" >&2
		echo -e "Updated twilight data sent to your Allsky Website." >&2
		echo -e "${wBOLD}If you have the website open in a browser, please refresh the window.${wNBOLD}" >&2
		echo -en "${wNC}" >&2
	else
		echo -e "${wERROR}ERROR posting updated twilight data: ${RESULT}.${wNC}" >&2
	fi
fi

if [ "${DEBUG}" = "true" ]; then
	D="--debug"
else
	D=""
fi
# shellcheck disable=SC2128
if [[ ${WEBSITE_CONFIG} != "" && -d ${ALLSKY_WEBSITE} ]]; then
	"${ALLSKY_SCRIPTS}/updateWebsiteConfig.sh" ${D} "${WEBSITE_CONFIG[@]}" >&2
fi	# else the Website isn't installed on the Pi

if [[ ${RUN_POSTTOMAP} == "true" ]]; then
	"${ALLSKY_SCRIPTS}/postToMap.sh" --whisper --force ${D} ${POSTTOMAP_ACTION} >&2
fi

if [[ ${RESTARTING} == "false" && ${NEEDS_RESTART} == "true" ]]; then
	echo -en "${wOK}${wBOLD}" >&2
	echo "*** You must restart Allsky for your change to take affect. ***" >&2
	echo -en "${wNBOLD}${wNC}" >&2
fi


exit 0

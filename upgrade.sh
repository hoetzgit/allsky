#!/bin/bash

# Upgrade the current Allsky release, carrying current settings forward.

[[ -z ${ALLSKY_HOME} ]] && export ALLSKY_HOME="$( realpath "$( dirname "${BASH_ARGV0}" )" )"
ME="$( basename "${BASH_ARGV0}" )"

#shellcheck source-path=.
source "${ALLSKY_HOME}/variables.sh"					|| exit "${ALLSKY_EXIT_ERROR_STOP}"
#shellcheck source-path=scripts
source "${ALLSKY_SCRIPTS}/functions.sh"					|| exit "${ALLSKY_EXIT_ERROR_STOP}"
#shellcheck source-path=scripts
source "${ALLSKY_SCRIPTS}/installUpgradeFunctions.sh"	|| exit "${ALLSKY_EXIT_ERROR_STOP}"

#############  TODO: Changes to install.sh needed:
#	* Accept "--doUpgrade" argument which means we're doing an upgrade.
#		- Don't display "**** Welcome to the installer ****"
#		- Don't prompt for camera
#		- Don't prompt to reboot
#		- Don't prompt other things ??
#
#############
# TODO:
#	Check for symbolic links
#############

# shellcheck disable=SC2034
DISPLAY_MSG_LOG="${ALLSKY_LOGS}/upgrade.log"	# send log entries here


############################## functions
####
function do_initial_heading()
{
	local MSG

	MSG="Welcome to the ${SHORT_TITLE}!\n\n"
	MSG+="Your current Allsky release will be"
	if [[ ${NEWEST_VERSION} == "${ALLSKY_VERSION}" ]]; then
		MSG+=" reinstalled"
	else
		MSG+=" upgraded to ${NEWEST_VERSION}"
	fi
	MSG+=" and all settings and images maintained."

	if [[ -d ${ALLSKY_PRIOR_DIR} ]]; then
		MSG+="\n\n'${ALLSKY_PRIOR_DIR}' will be renamed to '${OLDEST_DIR}'."
	fi
	MSG+="\n\n'${ALLSKY_HOME}' will be renamed to '${ALLSKY_PRIOR_DIR}'."
	MSG+="\n\nThe new release will go in '${ALLSKY_HOME}'."

	MSG+="\n\n\nContinue?"
	if ! dialog --title "${TITLE}" --yesno "${MSG}" 25 "${T_WIDTH}" \
			3>&1 1>&2 2>&3; then
		display_msg --logonly info "User not ready to continue."
		clear
		exit 0
	fi
	clear
}

function check_for_current()
{
	local MSG

	if [[ ${NEWEST_VERSION} == "${ALLSKY_VERSION}" ]]; then
		MSG="STARTING REINSTALLATION OF ${ALLSKY_VERSION}.\n"
		display_msg --logonly info "${MSG}"

		MSG="\nThe current version of Allsky (${ALLSKY_VERSION}) is the newest version."
		MSG+="\n\nReinstalling the current version is useful"
		MSG+=" if it's corrupted, you just want to start over,"
		MSG+=" or the Allsky Team updated the current version in GitHub without"
		MSG+=" changing the version name (e.g., for an emergency fix)."
		MSG+="\n\nYour current settings and images will remain."
		MSG+="\n\nContinue?"
		if ! dialog --title "${TITLE}" --yesno "${MSG}" 25 "${T_WIDTH}" \
				3>&1 1>&2 2>&3; then
			display_msg --logonly info "User elected not to continue."
			clear
			display_msg --log note "\nNo changes made.\n"
			exit 0
		fi
	else
		MSG="STARTING UPGRADE OF ${ALLSKY_VERSION} to ${NEWEST_VERSION}.\n"
		display_msg --logonly info "${MSG}"
	fi
}

# Check if both the prior and the "oldest" directory exist.
# If so, we can't continue since we can't rename the prior directory to the oldest.
function check_for_oldest()
{
	[[ ! -d ${ALLSKY_PRIOR_DIR} ]] && return 0

	if [[ -d ${OLDEST_DIR} ]]; then
		local MSG="Directory '${OLDEST_DIR}' already exist."
		local MSG2="\n\nIf you want to upgrade to the newest release, either remove '${OLDEST_DIR}'"
		MSG2+=" or rename it to something else, then re-run this upgrade."
		dialog --title "${TITLE}" --msgbox "${MSG}${MSG2}" 25 "${T_WIDTH}" 3>&1 1>&2 2>&3
		display_msg --log info "${MSG}"
		exit 2
	fi

	display_msg --log progress "Renaming '${ALLSKY_PRIOR_DIR}' to '${OLDEST_DIR}."
	mv "${ALLSKY_PRIOR_DIR}" "${OLDEST_DIR}"
}


function restore_directories()
{
	display_msg --log info "Renaming '${ALLSKY_PRIOR_DIR}' back to '${ALLSKY_HOME}'."
	mv "${ALLSKY_PRIOR_DIR}" "${ALLSKY_HOME}"
	if [[ -d ${OLDEST_DIR} ]]; then
		display_msg --log info "Renaming '${OLDEST_DIR}' back to '${ALLSKY_PRIOR_DIR}'."
		mv "${OLDEST_DIR}" "${ALLSKY_PRIOR_DIR}"
	fi
}


#
function usage_and_exit()
{
	local RET=${1}
	exec >&2

	echo
	local USAGE="Usage: ${ME} [--help] [--debug] [--branch branch] [--doUpgrade] [--in-place] [--ssh]"
	if [[ ${RET} -eq 0 ]]; then
		echo "Upgrade the Allsky software to a newer version."
		echo -e "\n${USAGE}"
	else
		E_ "${USAGE}"
	fi
	echo "Arguments:"
	echo "   --help            Displays this message and exits."
	echo "   --debug           Displays debugging information."
	echo "   --branch branch   Uses 'branch' instead of the production '${ALLSKY_GITHUB_MAIN_BRANCH}' branch."
	echo "   --doUpgrade       Completes the upgrade."
	echo "   --in-place        Specifies an 'in-place' upgrade should be performed."
	echo "   --ssh             Use ssh with git clone.  For developers only."
	echo
	exit "${RET}"
}

####################### main part of program
#shellcheck disable=SC2124
ALL_ARGS="$@"

METHOD_IN_PLACE="In Place"
METHOD_REPLACE_ALL="Replace All"
CHOSEN_METHOD=""

##### Check arguments
OK="true"
HELP="false"
DEBUG="false"; DEBUG_ARG=""
# shellcheck disable=SC2119
BRANCH="$( get_branch )"
[[ -z ${BRANCH} ]] && BRANCH="${ALLSKY_GITHUB_MAIN_BRANCH}"
# Possible ACTION's: "upgrade" (to prepare things), "doUpgrade" (to actually do the upgrade)
ACTION="upgrade"
SSH="false"

while [[ $# -gt 0 ]]; do
	ARG="${1}"
	case "${ARG,,}" in
		--help)
			HELP="true"
			;;
		--debug)
			DEBUG="true"
			DEBUG_ARG="${ARG}"		# we can pass this to other scripts
			;;
		--branch)
			BRANCH="${2}"
			shift
			;;
		--doupgrade)
			ACTION="doUpgrade"
			;;
		--in-place)
			CHOSEN_METHOD="${METHOD_IN_PLACE}"
			;;
		--ssh)
			SSH="true"
			;;
		-*)
			E_ "Unknown argument: '${ARG}'." >&2
			OK="false"
			;;

		*)
			break	# end of arguments
			;;
	esac
	shift
done
[[ ${HELP} == "true" ]] && usage_and_exit 0
[[ ${OK} == "false" || $# -ne 0 ]] && usage_and_exit 1
[[ ${DEBUG} == "true" ]] && echo "Running: ${ME} ${ALL_ARGS}"

cd || exit "${ALLSKY_EXIT_ERROR_STOP}"

if [[ ! -d ${ALLSKY_CONFIG} ]]; then
	MSG="Allsky does not appear to be installed; cannot continue."
	MSG2="Directory '${ALLSKY_CONFIG}' does not exist."
	display_msg --log error "${MSG}" "${MSG2}"
	echo
	exit 2
fi

if [[ "${ACTION}" != "upgrade" ]]; then
	# we're continuing where we left off, so don't welcome again.
	display_msg --log progress "Continuing the upgrade..."
fi

##### Calculate whiptail sizes
T_WIDTH="$( calc_wt_size )"

SHORT_TITLE="Allsky Upgrader"
TITLE="${SHORT_TITLE} - ${ALLSKY_VERSION}"
OLDEST_DIR="${ALLSKY_PRIOR_DIR/OLD/OLDEST}"

if [[ ${ACTION} == "upgrade" ]]; then
	display_header "Welcome to the ${SHORT_TITLE}"

	# First part of upgrade, executed by user in ${ALLSKY_HOME}.
	if ! NEWEST_VERSION="$( "${ALLSKY_UTILITIES}/getNewestAllskyVersion.sh" --branch "${BRANCH}" --version-only 2>&1 )" ; then
		MSG="Unable to determine newest version; cannot continue."
		if [[ ${BRANCH} != "${ALLSKY_GITHUB_MAIN_BRANCH}" ]];
		then
			MSG2="Make sure '${BRANCH}' is a valid branch in GitHub."
		else
			MSG2=""
		fi
		display_msg --log error "${MSG}" "${MSG2}"
		display_msg --logonly info "${NEWEST_VERSION}"		# is the error message.
		echo
		exit 2
	fi
	check_for_current

	# Ask user how they want to upgrade.
if true; then
	MSG="\n"
	MSG+="There are two ways to upgrade Allsky:"
	MSG+="\n"
	MSG+="\n1. ${METHOD_IN_PLACE}"
	MSG+="\n   This overwrites existing Allsky files on your Pi that have been"
	MSG+="\n   updated in GitHub, and is the preferred method for POINT RELEASES or"
	MSG+="\n   unless the Allsky Team suggests the method below."
	if [[ -d ${ALLSKY_PRIOR_DIR} ]]; then
		MSG+="\n   It does not use or update ${ALLSKY_PRIOR_DIR}."
	fi
	MSG+="\n   NOTE: If you have changed any Allsky source files this method"
	MSG+="\n   will not work."
	MSG+="\n"
	MSG+="\n2. ${METHOD_REPLACE_ALL}"
	MSG+="\n   This moves '${ALLSKY_HOME}' to '${ALLSKY_PRIOR_DIR}' then"
	MSG+="\n   recreates '${ALLSKY_HOME}' with the newest release from GitHub."
	MSG+="\n   It is safer than the method above but takes longer, and"
	MSG+="\n   is the preferred method for MAJOR updates or when you don't want"
	MSG+="\n   to overwrite the current release."
	MSG+="\n \nPick the upgrade method:"

#XXX	MSG+="\n\n\nYou will be prompted for which method to use in the next screen."

	HEIGHT="$( echo -e "${MSG}" | wc -l )"
	(( HEIGHT += 10 ))

if false; then
	dialog \
		--title "${SHORT_TITLE}" --msgbox "${MSG}" \
		"${HEIGHT}" "${T_WIDTH}"   3>&1 1>&2 2>&3
	if [[ $? -ne 0 ]]; then
		clear
		display_msg --log progress "\nNo changes made.\n"
		exit 0
	fi
fi

	X="$( dialog \
		--title "${SHORT_TITLE}" \
		--menu "${MSG}" "${HEIGHT}" "${T_WIDTH}" 2 \
			1 "${METHOD_IN_PLACE}" \
			2 "${METHOD_REPLACE_ALL}" \
		3>&1 1>&2 2>&3 )"
	clear

	if [[ ${X} -eq 1 ]]; then
		CHOSEN_METHOD="${METHOD_IN_PLACE}"
	elif [[ ${X} -eq 2 ]]; then
		CHOSEN_METHOD="${METHOD_REPLACE_ALL}"
	else
		MSG="User elected to not continue while picking an upgrade method."
		display_msg --logonly info "${MSG}"
		display_msg --log progress "\nNo changes made - no upgrade method chosen.\n"
		exit 0
	fi
else
# TODO: FIX: remove "else" when "Replace All" is implemented.
	CHOSEN_METHOD="${METHOD_IN_PLACE}"	# XXXX

	MSG="\n"
	MSG+="\nThis upgrade will download the newest files from GitHub and"
	MSG+="\ninstall them in '${ALLSKY_HOME}', overwriting the existing files."
	MSG+="\n"
	MSG+="\nNOTE: If you have changed any Allsky source files you must do a 'normal'"
	MSG+="\nupgrade using 'git clone' - see the documentation for instructions."
	MSG+="\n"
	MSG+="\n\nContinue?"
	HEIGHT="$( echo -e "${MSG}" | wc -l )"
	(( HEIGHT += 5 ))
	dialog \
		--title "${SHORT_TITLE}" --yesno "${MSG}" \
		"${HEIGHT}" 80   3>&1 1>&2 2>&3
	RET=$?
	clear
	if [[ ${RET} -ne 0 ]]; then
		display_msg --log progress "\nNo changes made.\n"
		exit 0
	fi
fi

	if [[ ${CHOSEN_METHOD} == "${METHOD_IN_PLACE}" ]]; then
		display_msg --log progress "Stopping Allsky"
		sudo systemctl stop allsky

		cd "${ALLSKY_HOME}"	|| exit "${ALLSKY_EXIT_ERROR_STOP}"

		display_msg --log progress "Getting new files from GitHub"
		X="$( git pull 2>&1 )"
		if [[ $? -ne 0 ]]; then
			if echo "${X}" | grep -i --silent -n "would be overwritten" ; then
				FILES="$( echo -e "${X}" | grep "^	" )"	# TAB
				MSG="You have un-checked out files, cannot continue:\n${FILES}"
			else
				MSG="Unable to get new files: ${X}"
			fi
			display_msg --log error "${MSG}" "Contact the Allsky Team"
			exit "${ALLSKY_EXIT_ERROR_STOP}"
		fi

		# This script may have been updated so re-run it.
		# shellcheck disable=SC2093
		exec "${ALLSKY_HOME}/${ME}" --doUpgrade --in-place		# should not return

		display_msg --log error "Unable to continue the upgrade."
		exit "${ALLSKY_EXIT_ERROR_STOP}"

	else		# move ${ALLSKY_HOME}

		# XXXXX   no longer needed?   do_initial_heading

		check_for_oldest

		display_msg --log progress "Stopping Allsky"
		stop_Allsky

		display_msg --log progress "Renaming '${ALLSKY_HOME}' to '${ALLSKY_PRIOR_DIR}'."
		mv "${ALLSKY_HOME}" "${ALLSKY_PRIOR_DIR}" || exit "${ALLSKY_EXIT_ERROR_STOP}"

		# Keep using same log file which is now in the "prior" directory.
		DISPLAY_MSG_LOG="${DISPLAY_MSG_LOG/${ALLSKY_HOME}/${ALLSKY_PRIOR_DIR}}"

		R="${ALLSKY_GITHUB_ROOT}/${ALLSKY_GITHUB_ALLSKY_REPO}.git"
		if [[ ${SSH} == "true" ]]; then
			R="${R/https:??/git@}"
		fi
		display_msg --log progress "Running: git clone --depth=1 --recursive --branch '${BRANCH}' '${R}'"
		display_msg note "" "This will take a minute or two."
		if ! ERR="$( git clone --depth=1 --recursive --branch "${BRANCH}" "${R}" 2>&1 )" ; then
			display_msg --log error "'git clone' failed." " ${ERR}"
			restore_directories
			exit 3
		fi

		cd "${ALLSKY_HOME}" || exit "${ALLSKY_EXIT_ERROR_STOP}"

		# --doUpgrade tells it to use prior version without asking and to not display header,
		# change messages to say "upgrade", not "install", etc.
		# shellcheck disable=SC2086,SC2291
		X="$(
#shellcheck disable=SC2116		# XXXXXXXXX temporary
echo XXX		./install.sh ${DEBUG_ARG} --branch "${BRANCH}" --doUpgrade
		)"
		RET=$?
		display_msg --logonly info "ENDING UPGRADE."
		if [[ ${RET} -ne 0 ]]; then
			display_msg --log warning "install.sh failed."  "Contact the Allsky Team"
			exit "${RET}"
		fi
		display_msg --log progress "The upgrade is complete."  "  Go to the WebUI to restart Allsky.\n"
	fi

elif [[ ${ACTION} == "doUpgrade" ]]; then
	if [[ ${CHOSEN_METHOD} == "${METHOD_IN_PLACE}" ]]; then
		X="$( "${ALLSKY_UTILITIES}/allsky-config.sh" recreate_files 2>&1 )"
		if [[ $? -ne 0 ]]; then
			MSG="Unable to update files: ${X}"
			display_msg --log error "${MSG}" "Contact the Allsky Team"
			exit 1
		fi
		display_msg --log progress "Files updated."  "  Go to the WebUI to restart Allsky.\n"
		display_msg --logonly info "Updated files:\n${X}"
		display_msg --logonly info "ENDING UPGRADE."
		exit 0
	else
:
	# XXXX TODO: add code
	fi
fi

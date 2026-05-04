#!/bin/bash

# This scripts is similar to "raspi-config" but for Allsky.
# It's a command-line method to view and set certain Allsky items.

# Allow this script to be executed manually, which requires several variables to be set.
[[ -z ${ALLSKY_HOME} ]] && export ALLSKY_HOME="$( realpath "$( dirname "${BASH_ARGV0}" )/.." )"
ME="$( basename "${BASH_ARGV0}" )"

#shellcheck source-path=.
source "${ALLSKY_HOME}/variables.sh"					|| exit "${ALLSKY_EXIT_ERROR_STOP}"
#shellcheck source-path=scripts
source "${ALLSKY_SCRIPTS}/functions.sh"					|| exit "${ALLSKY_EXIT_ERROR_STOP}"
#shellcheck source-path=scripts
source "${ALLSKY_SCRIPTS}/installUpgradeFunctions.sh"	|| exit "${ALLSKY_EXIT_ERROR_STOP}"

# Recreate files after a "git pull" or whenever any "parent" file changes.
# It's very possible some of the files don't need updating, but it's quick to
# update them and not always quick to check if they need updating.

if [[ ${1} == "--help" ]]; then
	echo
	W_ "Usage: ${ME}  ${ME_F}"
	echo
	echo "Recreates files when their 'parent' files change, e.g., a '.repo' file."
	exit 0
fi

echo "* Updating variables.json file."
create_variables_json ""		# Should come first so other steps get the newest file.

echo "* Updating sudoers file."
create_sudoers

echo "* Updating options file."
create_options_file --no-settings-file

echo "* Updating config_repo files."
update_repo_files

create_links "allsky-config"

echo "* Updating variables used by C programs and running 'make' if needed."
X="$( update_allsky_common "true" 2>&1 )"	# "true" means run "make" if needed
if [[ $? -ne 0 ]]; then
	W_ "WARNING: ${X}" >&2
fi

echo "* Updating lighttpd config file and restarting the service."
create_lighttpd_config_file ""
X="$( sudo systemctl restart lighttpd 2>&1 )"
if [[ $? -ne 0 ]]; then
	W_ "WARNING: unable to restart lighttpd service in ${ME_F}: ${X}" >&2
fi

echo "* Updating list of RPi supported cameras."
# true == ignore errors.  ${CMD} will be "" if no command found.
CMD="$( determineCommandToUse "false" "" "true" 2> /dev/null )"
RET=$?		# return of 2 means no command was found
[[ ${RET} -ne 0 ]] && CMD=""
# Will create full file is CMD == "".  "true" is to force creation.
setup_rpi_supported_cameras "${CMD}" "true"

echo "* Copying some ${ALLSKY_REPO} files to ${ALLSKY_CONFIG}."
copy_repo_files

exit 0

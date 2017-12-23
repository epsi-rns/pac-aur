#!/usr/bin/env bash

#
# based on pacaur.
# an AUR helper that minimizes user interaction
# original code at https://github.com/rmarquis/pacaur
#

version="0.0.10"
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

#
# Config
#

. ${DIR}/config.bash

#
# functions
#

. ${DIR}/helper.bash
#. ${DIR}/functions.bash

#
# Parse Arguments
#

. ${DIR}/options.bash
. ${DIR}/prepare.bash
. ${DIR}/message.bash

get_short_arguments
get_options_from_arguments "$@"
set_color_arguments
sanity_check
deprecation_warning

#
# Execute
#

. ${DIR}/operations.bash
. ${DIR}/operations/classify.bash
. ${DIR}/operations/docore.bash
. ${DIR}/operations/cower.bash
. ${DIR}/operations/checks.bash
. ${DIR}/operations/checkupdates.bash
. ${DIR}/operations/get.bash
. ${DIR}/operations/json.bash
. ${DIR}/operations/dependencies.bash
. ${DIR}/operations/packages.bash
. ${DIR}/operations/interactive.bash
. ${DIR}/operations/cleancache.bash

execute_operation $operation

# vim:set ts=4 sw=2 et:

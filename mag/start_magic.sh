#!/bin/bash
# Check if PDKPATH is set, if not try to guess relative to this script
if [ -z "$PDKPATH" ]; then
    # Assuming this script is in mag/ and dependencies are in ../dependencies
    script_dir=$(dirname "$(realpath "$0")")
    export PDK_ROOT=$(realpath "$script_dir/../dependencies/pdks")
    export PDK=sky130B
    export PDKPATH=$PDK_ROOT/$PDK
    echo "PDKPATH not set. Defaulting to $PDKPATH"
fi

# In case magicrc file is not in local folder
magic -rcfile $PDKPATH/libs.tech/magic/sky130B.magicrc "$@"

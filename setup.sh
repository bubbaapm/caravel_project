#!/bin/bash
# setup.sh
# Source this file to set environment variables for the project.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

export PROJECT_ROOT="$SCRIPT_DIR"
export PDK_ROOT="${PROJECT_ROOT}/dependencies/pdks"
export PDK=sky130B
export PDKPATH="${PDK_ROOT}/${PDK}"
export CARAVEL_ROOT="${PROJECT_ROOT}/caravel"
export OPENLANE_ROOT="${PROJECT_ROOT}/dependencies/openlane_src"

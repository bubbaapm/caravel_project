#!/bin/bash

# Check if a layout name was provided
if [ -z "$1" ]; then
    echo "Usage: $0 <layout_name>"
    exit 1
fi

CELL_NAME=$1

echo "--- Preparing netlists for $CELL_NAME ---"

# 1. Rename the layout-extracted spice file to avoid collision
if [ -f "${CELL_NAME}.spice" ]; then
    mv "${CELL_NAME}.spice" "${CELL_NAME}Mag.spice"
    echo "Renamed existing spice to ${CELL_NAME}Mag.spice"
else
    echo "Warning: ${CELL_NAME}.spice not found. Skipping rename."
fi

# 2. Copy the fresh schematic spice file from xschem
if [ -f "$HOME/.xschem/simulations/${CELL_NAME}.spice" ]; then
    # Added the "." at the end so it knows where to paste it
    cp "$HOME/.xschem/simulations/${CELL_NAME}.spice" .
    echo "Copied fresh schematic netlist from xschem simulations."
else
    echo "Error: Source netlist ~/.xschem/simulations/${CELL_NAME}.spice not found!"
    exit 1
fi

# 3. Run Netgen LVS in batch mode
echo "--- Running Netgen LVS ---"
netgen -batch lvs \
    "${CELL_NAME}.spice ${CELL_NAME}" \
    "${CELL_NAME}Mag.spice ${CELL_NAME}" \
    sky130B_setup.tcl

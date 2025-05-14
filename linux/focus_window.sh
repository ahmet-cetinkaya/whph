#!/bin/bash

# focus_window.sh - A script to bring a window to foreground on Linux using wmctrl
# Usage: ./focus_window.sh [window_title]

# Set default window title if not provided
WINDOW_TITLE=${1:-"whph"}

# Function to log debug messages
log_debug() {
    echo "[DEBUG] $1" >&2
}

# Check if wmctrl is installed
if ! command -v wmctrl &> /dev/null; then
    log_debug "wmctrl is not installed. Please install it using your package manager."
    exit 1
fi

# Get a list of all windows
window_list=$(wmctrl -l)
log_debug "Current windows: $window_list"

# First try to find the exact app window (not the editor)
if echo "$window_list" | grep -q " whph$"; then
    # Get the window ID for the exact match "whph"
    window_id=$(echo "$window_list" | grep " whph$" | head -n 1 | awk '{print $1}')
    log_debug "Found exact window ID for 'whph': $window_id"
    wmctrl -i -a "$window_id"
    exit 0
fi

# If exact match not found, try with any window containing whph
if echo "$window_list" | grep -q -i "whph"; then
    # Get all window IDs that match, excluding editor windows
    echo "$window_list" | grep -i "whph" | grep -v "Code" | while read -r window_line; do
        window_id=$(echo "$window_line" | awk '{print $1}')
        log_debug "Focusing window with ID: $window_id"
        wmctrl -i -a "$window_id"
        exit 0
    done

    # If no non-editor windows found, try any whph window
    window_id=$(echo "$window_list" | grep -i "whph" | head -n 1 | awk '{print $1}')
    log_debug "Focusing any whph window with ID: $window_id"
    wmctrl -i -a "$window_id"
    exit 0
fi

# Fallback to standard methods
log_debug "No specific window found, trying standard methods"

# Try with exact app name
log_debug "Trying to focus window by name: whph"
wmctrl -a "whph"

# Try with class name
log_debug "Trying to focus window by class name: whph"
wmctrl -x -a "whph"

log_debug "Window focusing attempts completed"
exit 0

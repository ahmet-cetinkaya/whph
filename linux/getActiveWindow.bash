#!/bin/bash

# Set to 1 to enable debug logging
DEBUG=0

# Logger function for debugging
log_debug() {
    if [[ $DEBUG -eq 1 ]]; then
        echo "[DEBUG] $1" >&2
    fi
}

log_error() {
    echo "[ERROR] $1" >&2
}

# WindowInfo class equivalent (struct-like behavior in bash)
# Represents active window information
declare -A WINDOW_INFO=(
    [title]="unknown"
    [application]="unknown"
)

# IWindowDetector interface equivalent (implemented through functions)
# Abstract base for window detection strategies

# X11WindowDetector implementation
detect_window_x11() {
    log_debug "Using X11 detection strategy"
    
    if ! command -v xprop &> /dev/null; then
        log_error "xprop command not found. Please install x11-utils."
        return 1
    fi
    
    # Get window ID with error handling
    local window_id
    window_id=$(xprop -root 2>/dev/null | grep '_NET_ACTIVE_WINDOW(WINDOW)' | awk '{print $5}')
    
    if [[ -z "$window_id" || "$window_id" == "0x0" ]]; then
        log_debug "Failed to get active window ID"
        return 1
    fi
    
    log_debug "Active window ID: $window_id"
    
    # Get window title with error handling
    local window_title
    window_title=$(xprop -id "$window_id" 2>/dev/null | grep '^WM_NAME' | cut -d '"' -f 2)
    
    # Get window PID with error handling
    local window_pid
    window_pid=$(xprop -id "$window_id" 2>/dev/null | grep '^_NET_WM_PID' | awk -F '= ' '{print $2}')
    
    if [[ -z "$window_pid" ]]; then
        log_debug "Failed to get window PID"
    else
        log_debug "Window PID: $window_pid"
    fi
    
    # Get process name
    local process_name="unknown"
    if [[ -n "$window_pid" ]]; then
        if [[ -e "/proc/$window_pid/comm" ]]; then
            process_name=$(cat "/proc/$window_pid/comm" 2>/dev/null)
        else
            process_name=$(ps -p "$window_pid" -o comm= 2>/dev/null)
        fi
    fi
    
    # Update window info
    if [[ -n "$window_title" ]]; then
        WINDOW_INFO[title]="$window_title"
    fi
    
    if [[ -n "$process_name" && "$process_name" != "unknown" ]]; then
        WINDOW_INFO[application]="$process_name"
    fi
    
    return 0
}

# GnomeWaylandDetector implementation
detect_window_gnome_wayland() {
    log_debug "Using GNOME Wayland detection strategy"
    
    if ! command -v gdbus &> /dev/null; then
        log_debug "gdbus command not found"
        return 1
    fi
    
    if ! pgrep -f gnome-shell &> /dev/null; then
        log_debug "GNOME Shell not running"
        return 1
    fi
    
    # Get window title with error handling
    local window_info
    window_info=$(gdbus call --session --dest org.gnome.Shell \
        --object-path /org/gnome/Shell \
        --method org.gnome.Shell.Eval \
        "global.display.focus_window?.get_title()" 2>/dev/null)
        
    if [[ "$window_info" != *"true"* ]]; then
        log_debug "Failed to get window title from GNOME Shell"
        
        # Try alternative method
        window_info=$(gdbus call --session --dest org.gnome.Shell \
            --object-path /org/gnome/Shell \
            --method org.gnome.Shell.Eval \
            "global.get_window_actors().find(a => a.meta_window.has_focus())?.meta_window.get_title()" 2>/dev/null)
            
        if [[ "$window_info" != *"true"* ]]; then
            log_debug "Alternative method also failed"
            return 1
        fi
    fi
    
    local window_title
    window_title=$(echo "$window_info" | sed -e "s/^(true, //g" -e "s/)$//g" -e "s/[\"']//g")
    log_debug "Window title: $window_title"
    
    # Get application ID via DBus
    local app_id="unknown"
    local desktop_app_info
    desktop_app_info=$(gdbus call --session --dest org.gnome.Shell \
        --object-path /org/gnome/Shell \
        --method org.gnome.Shell.Eval \
        "global.display.focus_window?.get_gtk_application_id() || global.display.focus_window?.get_wm_class()" 2>/dev/null)
        
    if [[ "$desktop_app_info" == *"true"* ]]; then
        app_id=$(echo "$desktop_app_info" | sed -e "s/^(true, //g" -e "s/)$//g" -e "s/[\"']//g")
    fi
    
    if [[ -z "$app_id" || "$app_id" == "null" || "$app_id" == "(null)" ]]; then
        # Try to get app ID through PID
        local app_pid
        app_pid=$(ps aux | grep -i "$window_title" | grep -v "grep\|bash" | head -n 1 | awk '{print $2}')
        if [[ -n "$app_pid" ]]; then
            if [[ -e "/proc/$app_pid/comm" ]]; then
                app_id=$(cat "/proc/$app_pid/comm" 2>/dev/null)
            else
                app_id=$(ps -p "$app_pid" -o comm= 2>/dev/null)
            fi
        fi
    fi
    
    # Update window info
    if [[ -n "$window_title" ]]; then
        WINDOW_INFO[title]="$window_title"
    fi
    
    if [[ -n "$app_id" && "$app_id" != "null" && "$app_id" != "(null)" ]]; then
        WINDOW_INFO[application]="$app_id"
    fi
    
    return 0
}

# SwayWaylandDetector implementation
detect_window_sway_wayland() {
    log_debug "Using Sway Wayland detection strategy"
    
    if ! command -v swaymsg &> /dev/null || ! command -v jq &> /dev/null; then
        log_debug "swaymsg or jq command not found"
        return 1
    fi
    
    # Check if Sway is running
    if ! pgrep -f sway &> /dev/null; then
        log_debug "Sway not running"
        return 1
    fi
    
    # Get active window info
    local active_window_info
    active_window_info=$(swaymsg -t get_tree 2>/dev/null | jq -r '.. | select(.focused? == true)' 2>/dev/null)
    
    if [[ -z "$active_window_info" ]]; then
        log_debug "Failed to get active window info from Sway"
        return 1
    fi
    
    # Extract window title and app ID
    local window_title
    window_title=$(echo "$active_window_info" | jq -r '.name' 2>/dev/null)
    
    local app_id
    app_id=$(echo "$active_window_info" | jq -r '.app_id // .window_properties.class' 2>/dev/null)
    
    if [[ "$app_id" == "null" || -z "$app_id" ]]; then
        local window_pid
        window_pid=$(echo "$active_window_info" | jq -r '.pid' 2>/dev/null)
        
        if [[ -n "$window_pid" && "$window_pid" != "null" ]]; then
            if [[ -e "/proc/$window_pid/comm" ]]; then
                app_id=$(cat "/proc/$window_pid/comm" 2>/dev/null)
            else
                app_id=$(ps -p "$window_pid" -o comm= 2>/dev/null)
            fi
        fi
    fi
    
    # Update window info
    if [[ -n "$window_title" && "$window_title" != "null" ]]; then
        WINDOW_INFO[title]="$window_title"
    fi
    
    if [[ -n "$app_id" && "$app_id" != "null" ]]; then
        WINDOW_INFO[application]="$app_id"
    fi
    
    return 0
}

# KdeWaylandDetector implementation
detect_window_kde_wayland() {
    log_debug "Using KDE Wayland detection strategy"
    
    if ! command -v qdbus &> /dev/null; then
        log_debug "qdbus command not found"
        return 1
    fi
    
    if ! pgrep -f "plasmashell" &> /dev/null; then
        log_debug "KDE Plasma not running"
        return 1
    fi
    
    # Get window ID
    local window_id
    window_id=$(qdbus org.kde.KWin /KWin activeWindow 2>/dev/null)
    
    if [[ -z "$window_id" ]]; then
        log_debug "Failed to get active window ID from KDE"
        return 1
    fi
    
    # Get window info
    local window_info
    window_info=$(qdbus org.kde.KWin /KWin getWindowInfo "$window_id" 2>/dev/null)
    
    if [[ -z "$window_info" ]]; then
        log_debug "Failed to get window info from KDE"
        return 1
    fi
    
    # Extract window title and application
    local window_title
    window_title=$(echo "$window_info" | grep "Caption:" | sed 's/Caption: //g')
    
    local app_id
    app_id=$(echo "$window_info" | grep "resourceClass:" | sed 's/resourceClass: //g')
    
    if [[ -z "$app_id" || "$app_id" == "unknown" ]]; then
        # Try to get app ID through PID info in window info
        local window_pid
        window_pid=$(echo "$window_info" | grep "pid:" | sed 's/pid: //g')
        
        if [[ -n "$window_pid" ]]; then
            if [[ -e "/proc/$window_pid/comm" ]]; then
                app_id=$(cat "/proc/$window_pid/comm" 2>/dev/null)
            else
                app_id=$(ps -p "$window_pid" -o comm= 2>/dev/null)
            fi
        fi
    fi
    
    # Update window info
    if [[ -n "$window_title" ]]; then
        WINDOW_INFO[title]="$window_title"
    fi
    
    if [[ -n "$app_id" ]]; then
        WINDOW_INFO[application]="$app_id"
    fi
    
    return 0
}

# WlrootsWaylandDetector implementation
detect_window_wlroots_wayland() {
    log_debug "Using wlroots-based Wayland detection strategy"
    
    # Try hyprctl for Hyprland
    if command -v hyprctl &> /dev/null; then
        log_debug "Detected Hyprland"
        
        local active_window
        active_window=$(hyprctl activewindow -j 2>/dev/null)
        
        if [[ -n "$active_window" ]]; then
            if command -v jq &> /dev/null; then
                local window_title
                window_title=$(echo "$active_window" | jq -r '.title' 2>/dev/null)
                
                local app_id
                app_id=$(echo "$active_window" | jq -r '.class' 2>/dev/null)
                
                # Update window info
                if [[ -n "$window_title" && "$window_title" != "null" ]]; then
                    WINDOW_INFO[title]="$window_title"
                fi
                
                if [[ -n "$app_id" && "$app_id" != "null" ]]; then
                    WINDOW_INFO[application]="$app_id"
                fi
                
                return 0
            fi
        fi
    fi
    
    # Try wayinfo for river and other wlroots-based compositors
    if command -v wayinfo &> /dev/null; then
        log_debug "Using wayinfo for wlroots compositor"
        
        local window_title
        window_title=$(wayinfo active-window-title 2>/dev/null)
        
        local app_id
        app_id=$(wayinfo active-window-app-id 2>/dev/null)
        
        # Update window info
        if [[ -n "$window_title" ]]; then
            WINDOW_INFO[title]="$window_title"
        fi
        
        if [[ -n "$app_id" ]]; then
            WINDOW_INFO[application]="$app_id"
        fi
        
        return 0
    fi
    
    return 1
}

# FallbackDetector implementation (uses ps to guess active window)
detect_window_fallback() {
    log_debug "Using fallback detection strategy"
    
    # Get the most recently active applications by CPU usage,
    # filtering out common background processes
    local exclude_pattern="bash|ps|grep|systemd|init|dbus|journald|pulseaudio|NetworkManager|getActiveWindow"
    local top_processes
    top_processes=$(ps -eo pid,pcpu,comm --sort=-pcpu | grep -v -E "$exclude_pattern" | head -n 5)
    
    if [[ -z "$top_processes" ]]; then
        log_debug "No suitable processes found"
        return 1
    fi
    
    log_debug "Top processes: $top_processes"
    
    # Get the likely user-facing application
    local app_pid
    local app_name
    app_pid=$(echo "$top_processes" | head -n 1 | awk '{print $1}')
    app_name=$(echo "$top_processes" | head -n 1 | awk '{print $3}')
    
    if [[ -z "$app_pid" || -z "$app_name" ]]; then
        log_debug "Failed to get app info from top processes"
        return 1
    fi
    
    # Try to get more descriptive name from cmdline
    local cmd_line=""
    if [[ -e "/proc/$app_pid/cmdline" ]]; then
        cmd_line=$(tr '\0' ' ' < "/proc/$app_pid/cmdline")
        log_debug "Command line: $cmd_line"
    fi
    
    # Update window info with best guess
    WINDOW_INFO[application]="$app_name"
    
    # Try to guess window title from cmdline or other sources
    if [[ -n "$cmd_line" ]]; then
        # Extract filename part if it contains a path
        if [[ "$cmd_line" == */* ]]; then
            local file_name
            file_name=$(basename "$(echo "$cmd_line" | awk '{print $1}')")
            if [[ -n "$file_name" ]]; then
                WINDOW_INFO[title]="$file_name"
            else
                WINDOW_INFO[title]="$app_name"
            fi
        else
            WINDOW_INFO[title]="$app_name"
        fi
    else
        WINDOW_INFO[title]="$app_name"
    fi
    
    return 0
}

# Main function that orchestrates window detection
detect_active_window() {
    # Detect display server type
    local display_server
    if [[ -n "$WAYLAND_DISPLAY" || "$XDG_SESSION_TYPE" == "wayland" ]]; then
        display_server="wayland"
        log_debug "Detected Wayland session"
    elif [[ -n "$DISPLAY" || "$XDG_SESSION_TYPE" == "x11" ]]; then
        display_server="x11"
        log_debug "Detected X11 session"
    else
        display_server="unknown"
        log_debug "Unknown display server"
    fi
    
    # Try detection strategies in order based on the display server
    local success=false
    
    if [[ "$display_server" == "x11" ]]; then
        # For X11, use the X11 detector
        if detect_window_x11; then
            success=true
        fi
    elif [[ "$display_server" == "wayland" ]]; then
        # For Wayland, try different implementations
        # Try GNOME
        if detect_window_gnome_wayland; then
            success=true
        # Try Sway
        elif detect_window_sway_wayland; then
            success=true
        # Try KDE
        elif detect_window_kde_wayland; then
            success=true
        # Try wlroots-based compositors
        elif detect_window_wlroots_wayland; then
            success=true
        fi
    fi
    
    # If all detectors failed, use the fallback method
    if ! $success; then
        log_debug "All regular detectors failed, trying fallback"
        detect_window_fallback
    fi
    
    # Output the window information
    echo "${WINDOW_INFO[title]},${WINDOW_INFO[application]}"
}

# Run the main function
detect_active_window

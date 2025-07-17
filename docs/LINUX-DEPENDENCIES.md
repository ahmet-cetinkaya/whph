# Linux Runtime Dependencies for WHPH

This document provides information about Linux system dependencies required to run the pre-built WHPH (Work Hard Play Hard) application on your system.

## About WHPH

WHPH is a productivity application that helps you manage tasks, develop habits, and track your time. The application requires certain system libraries to function properly on Linux.

## Installation

1. Download the latest pre-built Linux version from the [releases page](https://github.com/ahmet-cetinkaya/whph/releases)
2. Extract the downloaded archive
3. Install the required dependencies (see below)
4. Run the application: `./whph`

## Required Runtime Dependencies

### Arch Linux (Recommended for KDE users)

```bash
# Update system
sudo pacman -Syu

# Install essential runtime libraries
sudo pacman -S gtk3 gstreamer gst-plugins-base gst-plugins-good

# Install system integration
sudo pacman -S libayatana-appindicator libnotify

# Install window management tools (for app usage tracking)
sudo pacman -S xorg-xprop wmctrl xdotool  # For X11 systems
sudo pacman -S jq                         # For Sway/wlroots compositors

# SQLite is usually pre-installed, but if needed:
sudo pacman -S sqlite
```

### Ubuntu/Debian

```bash
# Update package list
sudo apt update

# Install essential runtime libraries
sudo apt install -y libgtk-3-0 libgstreamer1.0-0 libgstreamer-plugins-base1.0-0 \
                    libgstreamer-plugins-good1.0-0

# Install system integration
sudo apt install -y libayatana-appindicator3-1 libnotify4

# Install window management tools (for app usage tracking)
sudo apt install -y x11-utils wmctrl xdotool  # For X11 systems
sudo apt install -y jq                        # For Sway/wlroots compositors

# SQLite is usually pre-installed, but if needed:
sudo apt install -y sqlite3
```

### Fedora/RHEL/CentOS

```bash
# Update system
sudo dnf update

# Install essential runtime libraries
sudo dnf install -y gtk3 gstreamer1 gstreamer1-plugins-base gstreamer1-plugins-good

# Install system integration
sudo dnf install -y libayatana-appindicator-gtk3 libnotify

# Install window management tools (for app usage tracking)
sudo dnf install -y xorg-x11-utils wmctrl xdotool  # For X11 systems
sudo dnf install -y jq                             # For Sway/wlroots compositors

# SQLite is usually pre-installed, but if needed:
sudo dnf install -y sqlite
```

### openSUSE

```bash
# Update system
sudo zypper refresh && sudo zypper update

# Install essential runtime libraries
sudo zypper install -y gtk3 gstreamer gstreamer-plugins-base gstreamer-plugins-good

# Install system integration
sudo zypper install -y libayatana-appindicator3-1 libnotify4

# Install window management tools (for app usage tracking)
sudo zypper install -y xprop wmctrl xdotool  # For X11 systems
sudo zypper install -y jq                   # For Sway/wlroots compositors

# SQLite is usually pre-installed, but if needed:
sudo zypper install -y sqlite3
```

## Verification Steps

### 1. Check Required Libraries

```bash
# Check GTK3
pkg-config --modversion gtk+-3.0

# Check GStreamer
gst-inspect-1.0 --version

# Check if window management tools are available
which xprop wmctrl xdotool  # For X11 systems
which jq                    # For Wayland compositors
```

### 2. Test Audio System

```bash
# Check GStreamer plugins
gst-inspect-1.0 | grep -E "(audio|pulse|alsa)"

# Test audio playback (optional)
gst-launch-1.0 audiotestsrc ! autoaudiosink
```

### 3. Run the Application

```bash
# Navigate to extracted application directory
cd /path/to/whph

# Make executable if needed
chmod +x whph

# Run the application
./whph
```

## Desktop Environment Specific Notes

### KDE Plasma (Recommended for Arch Linux users)
- System tray integration works out of the box
- Window detection uses native KDE tools
- Best compatibility with the application

### GNOME
- Requires AppIndicator extension for system tray functionality
- Install "AppIndicator and KStatusNotifierItem Support" extension
- Window detection works via D-Bus calls

### Sway/i3/wlroots compositors
- Requires `jq` for window detection
- System tray support depends on your bar configuration (waybar, i3bar, etc.)
- Excellent Wayland support

### Hyprland
- Uses `hyprctl` for window management (usually pre-installed)
- Good Wayland support
- May require additional system tray configuration

## What Each Dependency Does

### Essential Runtime Libraries
- **GTK3**: Provides the user interface framework
- **GStreamer**: Handles audio playback for notifications and sounds
- **SQLite**: Database for local data storage (usually pre-installed)

### System Integration
- **libayatana-appindicator**: Enables system tray functionality
- **libnotify**: Enables desktop notifications

### Window Management (Optional but Recommended)
- **xprop, wmctrl, xdotool**: For app usage tracking on X11 systems
- **jq**: JSON parser needed for some Wayland compositors
- **Compositor-specific tools**: For advanced window management on Wayland

### Audio System
- **PulseAudio/PipeWire**: Audio server (usually pre-installed)
- **GStreamer plugins**: Additional audio format support

Most modern Linux distributions include the basic requirements by default. You typically only need to install the system integration packages and window management tools for full functionality.
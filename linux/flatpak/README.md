# WHPH Flatpak Package

This directory contains the Flatpak configuration for packaging and distributing WHPH (Work Hard Play Hard) as a Flatpak application.

## Prerequisites

Before building the Flatpak, ensure you have the following installed:

- **Flatpak**: The application distribution framework
- **Flatpak Builder**: Tool for building Flatpak applications
- **Git**: For version control (if building from repository)

### Installing Prerequisites on Different Distributions

#### Ubuntu/Debian:
```bash
sudo apt update
sudo apt install flatpak flatpak-builder
```

#### Fedora:
```bash
sudo dnf install flatpak flatpak-builder
```

#### Arch Linux:
```bash
sudo pacman -S flatpak flatpak-builder
```

#### Add Flathub Repository:
```bash
flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
```

## Building the Flatpak

### Automated Build (Recommended)

Use the provided build script for an automated build process:

```bash
cd linux/flatpak
./build-flatpak.sh
```

This script will:
1. Check for required dependencies
2. Install necessary runtimes and SDK extensions
3. Build the Flatpak application
4. Create a distributable `.flatpak` bundle

### Manual Build

If you prefer to build manually:

1. **Install required runtimes:**
   ```bash
   flatpak install flathub org.freedesktop.Platform//23.08
   flatpak install flathub org.freedesktop.Sdk//23.08
   flatpak install flathub org.freedesktop.Sdk.Extension.flutter//23.08
   ```

2. **Build the application:**
   ```bash
   cd linux/flatpak
   flatpak-builder --force-clean --sandbox --user --install-deps-from=flathub build-dir me.ahmetcetinkaya.whph.yml
   ```

3. **Create repository and bundle:**
   ```bash
   flatpak build-export repo build-dir
   flatpak build-bundle repo me.ahmetcetinkaya.whph.flatpak me.ahmetcetinkaya.whph
   ```

## Installing and Running

### Install the Flatpak:
```bash
flatpak install --user me.ahmetcetinkaya.whph.flatpak
```

### Run the application:
```bash
flatpak run me.ahmetcetinkaya.whph
```

### Create desktop shortcut (optional):
The application should automatically appear in your application menu after installation.

## Flatpak Configuration Details

### Application ID
- **ID**: `me.ahmetcetinkaya.whph`
- **Runtime**: `org.freedesktop.Platform//23.08`
- **SDK**: `org.freedesktop.Sdk//23.08`

### Permissions (finish-args)

The application requests the following permissions:

- **Display**: X11 and Wayland support for GUI
- **Audio**: PulseAudio access for notification sounds
- **Network**: Required for sync features
- **File System**: Access to home directory, documents, and downloads
- **D-Bus**: Desktop integration (notifications, file chooser, etc.)
- **Device**: DRI access for hardware acceleration

### Dependencies

- **Flutter SDK**: Provided via `org.freedesktop.Sdk.Extension.flutter`
- **GTK3**: For native Linux GUI components
- **libsecret**: For secure credential storage

## File Structure

```
linux/flatpak/
├── me.ahmetcetinkaya.whph.yml          # Flatpak manifest
├── me.ahmetcetinkaya.whph.metainfo.xml # Application metadata
├── build-flatpak.sh                    # Automated build script
└── README.md                           # This documentation
```

## Feature Limitations in Flatpak

### App Usage Tracking

Due to Flatpak's sandboxing security model, some native app usage tracking features have limited functionality:

**Limitations:**
- **Process monitoring**: Cannot access `/proc` filesystem (reserved by Flatpak)
- **Window manager tools**: Limited access to `xprop`, `wmctrl`, `swaymsg`, `hyprctl` within sandbox
- **Wayland compositor communication**: Restricted D-Bus access to window managers
- **System-level process detection**: Cannot enumerate all running applications

**What works:**
- ✅ Basic application launch and GUI functionality
- ✅ System tray integration
- ✅ D-Bus notifications
- ✅ File system access for data storage‍
- ✅ Desktop integration (icons, shortcuts)

**Workarounds:**
- App usage tracking may show limited information compared to native installation
- Some window detection features may fall back to basic process monitoring
- Consider using the native `.deb` or direct installation for full app usage tracking

### Wayland vs X11 Support

The application attempts to detect and use appropriate window management tools:
- **X11**: Uses `xprop` and X11 libraries (when available)
- **Wayland**: Attempts to use compositor-specific tools (`swaymsg`, `hyprctl`, GNOME Shell D-Bus)
- **Fallback**: Basic process monitoring when window manager tools unavailable

## Troubleshooting

### Common Issues

1. **Flutter SDK not found:**
   - Ensure `org.freedesktop.Sdk.Extension.flutter` is installed
   - Check that the SDK extension is available for the correct runtime version

2. **Build fails with permission errors:**
   - Make sure you're building with `--user` flag
   - Ensure the build directory has proper permissions

3. **Application doesn't start:**
   - Check if all required runtimes are installed
   - Verify the desktop file and executable paths are correct

4. **Missing dependencies:**
   - Run `flatpak install --user --reinstall me.ahmetcetinkaya.whph`
   - Check if base runtimes are properly installed

5. **App usage tracking not working:**
   - This is expected due to Flatpak sandboxing limitations
   - The app will show warnings like "which: no swaymsg in (/app/bin:/usr/bin)"
   - These warnings are harmless but indicate limited tracking functionality
   - For full app usage tracking, consider native installation

### Debug Mode

To run the application in debug mode:
```bash
flatpak run --devel --command=sh me.ahmetcetinkaya.whph
```

### Viewing Logs

To see application logs:
```bash
flatpak run --log-session-bus --log-system-bus --devel me.ahmetcetinkaya.whph
```

## Uninstalling

To remove the application:
```bash
flatpak uninstall --user me.ahmetcetinkaya.whph
```

To also remove unused runtimes:
```bash
flatpak uninstall --unused
```

## Publishing to Flathub

To publish this application to Flathub:

1. Fork the [Flathub repository](https://github.com/flathub/flathub)
2. Create a new repository named `me.ahmetcetinkaya.whph`
3. Submit the manifest files following [Flathub guidelines](https://docs.flathub.org/docs/for-app-authors/submission)
4. The Flathub team will review and publish your application

## Development

For development and testing:
- Use `--devel` flag when running for debugging
- Modify `finish-args` in the manifest for additional permissions
- Update `metainfo.xml` for application store listings

## License

This Flatpak configuration follows the same license as the main WHPH application (MIT License).
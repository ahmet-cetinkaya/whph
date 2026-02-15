# Flatpak Packaging Documentation

This document explains the permissions and external libraries used in the WHPH Flatpak packaging.

## Permissions (`finish-args`)

| Permission | Description & Justification |
| :--- | :--- |
| `--share=ipc` | **Inter-Process Communication**. Required for X11 compatibility and some Wayland compositors to share memory. |
| `--socket=fallback-x11` | **X11 Display Access**. Allows the app to run on X11 or XWayland. Required as a fallback if native Wayland is not available or has issues. |
| `--socket=wayland` | **Wayland Display Access**. Allows the app to run natively on Wayland compositors. |
| `--socket=pulseaudio` | **Audio Access**. Required for playing notification sounds or other audio feedback. |
| `--device=dri` | **GPU Acceleration**. Grants access to the Direct Rendering Infrastructure for hardware-accelerated graphics (Flutter). |
| `--talk-name=org.kde.StatusNotifierWatcher` | **System Tray (KDE/Generic)**. Required to register a system tray icon on KDE Plasma and other desktop environments that use this specific DBus name. |
| `--talk-name=org.gnome.Shell` | **Active Window / Tray (GNOME)**. Used to query window information on GNOME Shell via DBus for the "Active Window Detection" feature. |
| `--talk-name=org.kde.KWin` | **Active Window (KDE)**. Required to run KWin scripts via DBus to detect the active window title and class on KDE Plasma. |
| `--filesystem=xdg-config/kdeglobals:ro` | **KDE Theming**. Read-only access to KDE global configuration to respect user theme settings (colors, fonts). |
| `--filesystem=xdg-config/gtk-3.0:ro` | **GTK Theming**. Read-only access to GTK 3 configuration to respect user theme settings (colors, fonts). |
| `--talk-name=org.freedesktop.Settings` | **System Settings**. Allows reading system settings (like dark mode preference) via the XDG Settings Portal fallback/direct access. |
| `--talk-name=org.freedesktop.Flatpak` | **Sandbox Escape (Host Access)**. **CRITICAL**: Allows the app to run commands on the host system via `flatpak-spawn --host`. <br> **Usage**: This is strictly used by the "Active Window Detection" feature to run tools like `ps`, `journalctl`, and `qdbus` to determine the currently focused window title and application name, which is not possible from within the strict sandbox. |

## External Libraries (`modules`)

| Module | Purpose |
| :--- | :--- |
| `shared-modules` | **Flathub Shared Configs**. A repository of common build configurations for standard libraries. Used to import `intltool` and `libayatana-appindicator`. |
| `perl-xml-parser` | **Build Dependency**. A Perl module required to build `intltool`. It is only used during the build process and is cleaned up afterwards. |
| `intltool` | **Build Tool**. A set of tools to centralize translation of many different file formats. Required to build `libayatana-appindicator`. Imported via `shared-modules`. |
| `libayatana-appindicator` | **System Tray Support**. A library that provides support for "AppIndicators" (system tray icons) on Linux, used by the Flutter `tray_manager` plugin. Imported via `shared-modules`. |

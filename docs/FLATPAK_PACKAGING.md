# Flatpak Packaging Documentation

This document explains the permissions and external libraries used in the WHPH
Flatpak packaging.

## Package Information

| Field             | Value                                  | Description                                       |
| :---------------- | :------------------------------------- | :------------------------------------------------ |
| `id`              | `me.ahmetcetinkaya.whph`               | Unique application identifier on Flathub          |
| `runtime`         | `org.freedesktop.Platform`             | Base runtime providing core system libraries      |
| `runtime-version` | `25.08`                                | Version of the runtime to use                     |
| `sdk`             | `org.freedesktop.Sdk`                  | Development SDK for building the application      |
| `sdk-extensions`  | `org.freedesktop.Sdk.Extension.llvm20` | LLVM 20 extension for building native code        |
| `command`         | `whph`                                 | Command to execute when launching the application |

## Build Process

The packaging process is automated via `scripts/package_flatpak.sh`:

1.  **Cleanup**: Removes previous build artifacts and `repo` directory.
2.  **Configuration**: Uses `flatpak-flutter` to generate module definitions
    from `pubspec.yaml`.
3.  **Vendoring**: Copies required `shared-modules` (intltool,
    libayatana-appindicator) into the build context.
4.  **Building**: Runs `flatpak-builder` to compile the application and create a
    `.flatpak` bundle.
5.  **Integration**: Installs desktop entry, D-Bus service file, icons, and
    metainfo file to integrate the application with the desktop environment.
6.  **Flutter Build**: Executes Flutter build commands including running build
    runner and building the Linux release bundle with proper architecture
    support (x64/aarch64).
7.  **Output**:
    - `whph.flatpak`: The final installable bundle.
    - `repo/`: The OSTree repository.
    - `flathub/`: The directory ready for Flathub submission (manifest +
      generated sources).

## Packaging Structure

The Flatpak packaging is organized in `packaging/flatpak/`:

```
packaging/flatpak/
├── flatpak-flutter.yaml      # Main application manifest
├── flathub/                  # Flathub submission repository (submodule)
│   ├── me.ahmetcetinkaya.whph.yaml     # Flathub manifest
│   ├── me.ahmetcetinkaya.whph.metainfo.xml  # App metadata for Flathub
│   └── shared-modules/       # Shared module definitions for Flathub
│       └── libayatana-appindicator/    # System tray support definitions
└── flatpak-flutter/          # Flatpak Flutter tooling submodule
    ├── flatpak-flutter.py    # Main tool for generating Flutter modules
    └── ...                   # Additional tooling files
```

## Permissions (`finish-args`)

### Display

| Permission              | Description & Justification                                                                                                                |
| :---------------------- | :----------------------------------------------------------------------------------------------------------------------------------------- |
| `--share=ipc`           | **Inter-Process Communication**. Required for X11 compatibility and some Wayland compositors to share memory.                              |
| `--socket=fallback-x11` | **X11 Display Access**. Allows the app to run on X11 or XWayland. Required as a fallback if native Wayland is not available or has issues. |
| `--socket=wayland`      | **Wayland Display Access**. Allows the app to run natively on Wayland compositors.                                                         |

### Network

| Permission        | Description & Justification                                                                 |
| :---------------- | :------------------------------------------------------------------------------------------ |
| `--share=network` | **Network Access**. Required for "Sync Device" functionality to discover and connect peers. |

### Audio

| Permission            | Description & Justification                                                         |
| :-------------------- | :---------------------------------------------------------------------------------- |
| `--socket=pulseaudio` | **Audio Access**. Required for playing notification sounds or other audio feedback. |

### Device

| Permission     | Description & Justification                                                                                             |
| :------------- | :---------------------------------------------------------------------------------------------------------------------- |
| `--device=dri` | **GPU Acceleration**. Grants access to the Direct Rendering Infrastructure for hardware-accelerated graphics (Flutter). |

### System Tray / Notifications

| Permission                                  | Description & Justification                                                                                                                           |
| :------------------------------------------ | :---------------------------------------------------------------------------------------------------------------------------------------------------- |
| `--talk-name=org.kde.StatusNotifierWatcher` | **System Tray (KDE/Generic)**. Required to register a system tray icon on KDE Plasma and other desktop environments that use this specific DBus name. |
| `--talk-name=org.freedesktop.Notifications` | **Desktop Notifications**. Required to send desktop notifications to the user.                                                                        |

### Integration / Theming

| Permission                              | Description & Justification                                                                                                               |
| :-------------------------------------- | :---------------------------------------------------------------------------------------------------------------------------------------- |
| `--filesystem=xdg-config/kdeglobals:ro` | **KDE Theming**. Read-only access to KDE global configuration to respect user theme settings (colors, fonts).                             |
| `--filesystem=xdg-config/gtk-3.0:ro`    | **GTK 3 Theming**. Read-only access to GTK 3 user configuration to respect theme settings in GTK based environments.                      |
| `--filesystem=xdg-config/gtk-4.0:ro`    | **GTK 4 Theming**. Read-only access to GTK 4 user configuration to respect theme settings in newer GTK based environments.                |
| `--env=GSETTINGS_BACKEND=dconf`         | **GTK Settings Backend**. Sets the GSettings backend to dconf for proper integration with GNOME and other GTK-based desktop environments. |
| `--talk-name=org.freedesktop.Settings`  | **System Settings**. Allows reading system settings (like dark mode preference) via the XDG Settings Portal fallback/direct access.       |

### Window Management

| Permission                            | Description & Justification                                                                                                                                                                                                                                                                                                                                                                |
| :------------------------------------ | :----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `--talk-name=org.gnome.Shell`         | **Active Window / Tray (GNOME)**. Used to query window information on GNOME Shell via DBus for the "Active Window Detection" feature.                                                                                                                                                                                                                                                      |
| `--talk-name=org.kde.KWin`            | **Active Window (KDE)**. Required to run KWin scripts via DBus to detect the active window title and class on KDE Plasma.                                                                                                                                                                                                                                                                  |
| `--talk-name=org.kde.kwin.Scripting`  | **KWin Scripting Interface**. Additional interface for KWin scripting functionality used in active window detection on KDE.                                                                                                                                                                                                                                                                |
| `--talk-name=org.freedesktop.Flatpak` | **Sandbox Escape (Host Access)**. **CRITICAL**: Allows the app to run commands on the host system via `flatpak-spawn --host`. <br> **Usage**: This is strictly used by the "Active Window Detection" feature to run tools like `ps`, `journalctl`, and `qdbus` to determine the currently focused window title and application name, which is not possible from within the strict sandbox. |

## External Libraries (`modules`)

| Module                                                                     | Purpose                                                                                                                                                                              |
| :------------------------------------------------------------------------- | :----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `shared-modules/intltool/intltool-0.51.json`                               | **Build Tool**. A set of tools to centralize translation of many different file formats. Required to build `libayatana-appindicator`. Imported via `shared-modules`.                 |
| `shared-modules/libayatana-appindicator/libayatana-appindicator-gtk3.json` | **System Tray Support**. A library that provides support for "AppIndicators" (system tray icons) on Linux, used by the Flutter `tray_manager` plugin. Imported via `shared-modules`. |
| `perl-xml-parser`                                                          | **Build Dependency**. A Perl module required to build `intltool`. It is only used during the build process and is cleaned up afterwards.                                             |
| `whph`                                                                     | **Main Application**. The WHPH application module that builds the Flutter application and bundles all required assets, icons, desktop entries, and metainfo files.                   |
| `flutter`                                                                  | **Flutter SDK**. The Flutter framework source code downloaded and built as part of the Flatpak build process to ensure consistent and reproducible builds.                           |

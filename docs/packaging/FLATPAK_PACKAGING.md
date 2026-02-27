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
2.  **Manifest Selection**: Chooses one source manifest:
    - `flatpak-flutter.yaml` for local/CI bundle builds.
    - `flatpak-flutter.flathub.yaml` for Flathub builds (`--flathub`).
3.  **Configuration**: Uses `flatpak-flutter` to generate module definitions
    from `pubspec.yaml` into `flathub/`.
4.  **Local Override Staging**: For non-Flathub builds, copies
    `libayatana-appindicator-gtk3.override.json` into the generated `flathub/`
    directory.
5.  **Building**: Runs `flatpak-builder` to compile the application and create a
    `.flatpak` bundle.
6.  **Integration**: Installs desktop entry, D-Bus service file, icons, and
    metainfo file to integrate the application with the desktop environment.
7.  **Flutter Build**: Executes Flutter build commands including running build
    runner and building the Linux release bundle with proper architecture
    support (x64/aarch64).
8.  **Output**:
    - `whph-v<VERSION>-linux.flatpak`: The final installable bundle.
    - `repo/`: The OSTree repository.
    - `flathub/`: The directory ready for Flathub submission (manifest +
      generated sources).

## Packaging Structure

The Flatpak packaging is organized in `packaging/flatpak/`:

```
packaging/flatpak/
├── flatpak-flutter.yaml      # Local/CI source manifest (uses local Ayatana override)
├── flatpak-flutter.flathub.yaml  # Flathub source manifest (uses shared-modules)
├── libayatana-appindicator-gtk3.override.json  # Local/CI Ayatana override module
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

### Window Management

| Permission                            | Description & Justification                                                                                                                                                                                                                                                                                                                                                                |
| :------------------------------------ | :----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `--talk-name=org.gnome.Shell`         | **Active Window / Tray (GNOME)**. Used to query window information on GNOME Shell via DBus for the "Active Window Detection" feature.                                                                                                                                                                                                                                                      |
| `--talk-name=org.kde.KWin`            | **Active Window (KDE)**. Required to run KWin scripts via DBus to detect the active window title and class on KDE Plasma.                                                                                                                                                                                                                                                                  |
| `--talk-name=org.kde.kwin.Scripting`  | **KWin Scripting Interface**. Additional interface for KWin scripting functionality used in active window detection on KDE.                                                                                                                                                                                                                                                                |
| `--talk-name=org.freedesktop.Flatpak` | **Sandbox Escape (Host Access)**. **CRITICAL**: Allows the app to run commands on the host system via `flatpak-spawn --host`. <br> **Usage**: This is strictly used by the "Active Window Detection" feature to run tools like `ps`, `journalctl`, and `qdbus` to determine the currently focused window title and application name. <br> **Flathub Note**: This permission is removed in the Flathub build (`--flathub` flag) to comply with strict sandboxing rules, which limits active window tracking on some Wayland compositors. |

## External Libraries and Build Dependencies (`modules`)

The Flatpak manifest (`flatpak-flutter.yaml`) defines a series of modules that
are built in order. Some modules are prerequisite build tools for others.

| Module / Dependency       | Category             | Purpose & Justification                                                                                                                                                                    |
| :------------------------ | :------------------- | :----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `perl-xml-parser`         | **Build Dependency** | A Perl module required to build `intltool`. It is used only during the build process and is cleaned up (`cleanup: ["*"]`) afterwards.                                                      |
| `intltool`                | **Build Tool**       | A set of tools to centralize translation. It is required to build `libayatana-appindicator` and is built as an internal module within it.                                              |
| `libayatana-appindicator` | **Runtime Library**  | Provides support for **System Tray Icons** (AppIndicators) on Linux. This is required by the Flutter `tray_manager` plugin to show the app icon in the system tray.                        |
| `flutter`                 | **Runtime SDK**      | Included as a source within the `whph` module. The Flutter SDK is downloaded and built during the process to ensure a consistent, reproducible environment independent of the host system. |
| `whph`                    | **Application**      | The main application module. It uses the `flutter` SDK to compile the source code and bundles the resulting binary with its assets, desktop entries, and metadata.                         |

### Custom Ayatana Override (Why It Exists)

WHPH intentionally uses a local override module file:

- `packaging/flatpak/libayatana-appindicator-gtk3.override.json`

instead of relying only on the shared submodule definition for
`libayatana-appindicator`.

This override is required to keep Flatpak CI builds stable for the Flutter
`tray_manager` Linux plugin, which checks pkg-config for:

- `ayatana-appindicator3-0.1` (or `appindicator3-0.1`)

#### Root cause

In the default shared module flow, cleanup/install layout differences can remove
or relocate pkg-config metadata before downstream modules run, which causes
CMake/pkg-config resolution failures during:

- `libayatana-indicator` configure step
- `whph` module (`flutter build linux`) via `tray_manager`

#### What the override enforces

- Normalized install libdir (`-DCMAKE_INSTALL_LIBDIR=lib`) for Ayatana modules
- Preservation of required pkg-config metadata between module boundaries
- Patch path stability when building from generated manifests
- Stable `PKG_CONFIG_PATH` in `whph` build options (declared directly in source manifests)

#### Maintenance note

Do not remove this override unless the upstream shared module behavior is proven
stable for all of these checks in CI:

- `libayatana-ido3-0.4`
- `ayatana-indicator3-0.4`
- `ayatana-appindicator3-0.1`

### Module Dependency Chain

To support system tray icons in the Flutter application, the following
dependency chain is established in the manifest:

1.  **`perl-xml-parser`** (Needed by `intltool`, which is built internally by `libayatana-appindicator`)
2.  **`libayatana-appindicator`** (Needed by Flutter's tray plugin; builds its own `intltool`)
3.  **`whph`** (The final application, built using the `flutter` SDK source)

## Flathub Submission & Differences

When building for Flathub, we strictly adhere to sandbox guidelines and use
`flatpak-flutter.flathub.yaml`, where Flathub-specific differences are declared
directly (not patched dynamically by the script):

- `--talk-name=org.freedesktop.Flatpak` is omitted.
- `flutter build linux` includes `--dart-define=FLATHUB=true`.
- Ayatana module is referenced via `shared-modules/...` instead of local override.

Because of this, the Flathub version of WHPH cannot use `flatpak-spawn --host` to run absolute fallback heuristics or call specific Wayland compositor tools (like `swaymsg` or `hyprctl`). Users on these environments will see an in-app notice explaining the limitation.

### Installing Flatpak from Release
If you require full active window tracking on these unsupported Wayland compositors, you can install the fully-featured Flatpak directly from the GitHub releases:

1. Download the `whph-v<VERSION>-linux.flatpak` bundle from the latest [GitHub Release](https://github.com/ahmet-cetinkaya/whph/releases).
   You can also use `curl` to download it (replace `<VERSION>` with the desired version, e.g., `v0.22.1`):
   ```bash
   curl -L -O https://github.com/ahmet-cetinkaya/whph/releases/download/<VERSION>/whph-v<VERSION>-linux.flatpak
   ```
2. Install it using the Flatpak CLI (replace `<VERSION>` with the version you downloaded):

```bash
flatpak install --user whph-v<VERSION>-linux.flatpak
```

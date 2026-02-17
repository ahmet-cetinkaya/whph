# Inno Setup Packaging Documentation

This document explains the Inno Setup configuration for creating the Windows installer for WHPH.

## Packaging Structure

The Windows installer packaging is organized in `packaging/inno-setup/`:

```
packaging/inno-setup/
└── installer.iss     # Inno Setup script file
```

## Build Process

The packaging process is automated via the GitHub Actions CI workflow in `.github/workflows/flutter-ci.windows.yml`:

1.  **Environment Setup**: Installs Inno Setup on the runner and adds it to the PATH.
2.  **App Build**: Executes `fvm flutter build windows --release`.
3.  **Installer Configuration**:
    -   Extracts version from `src/pubspec.yaml`.
    -   Creates a temporary `.iss` file.
    -   Patches `AppVersion` and file source paths using PowerShell.
4.  **Compilation**: Runs `ISCC.exe` on the configured script.
5.  **Output**:
    -   `src/build/windows/installer/whph-setup.exe`: The final installable bundle.

## Manual Build

To build the installer manually on Windows:

1.  **Prerequisites**:
    -   Install [Inno Setup 6](https://jrsoftware.org/isinfo.php).
    -   Ensure `fvm` is configured if using it for Flutter.
2.  **Steps**:
    -   Run `fvm flutter build windows --release` in the `src` directory.
    -   From the project root, run:
        `"C:\Program Files (x86)\Inno Setup 6\ISCC.exe" packaging\inno-setup\installer.iss`

The installer will be created at `src\build\windows\installer\whph-setup.exe`.

## Installer Features

- **Modern Interface**: Uses the Inno Setup modern wizard style.
- **Architecture**: Native 64-bit (x64) installation.
- **Multi-language Support**: Automatically detects system language and supports:
  - English
  - Turkish (Türkçe)
- **Permissions**: Installs with lowest required privileges (no administrator rights required by default).
- **Shortcuts**: Optional desktop and quick launch shortcuts.
- **Cleanup**: Includes an uninstaller that can also clean up user data in `LocalAppData\WHPH`.

## Configuration Details (`installer.iss`)

The script defines several sections:

- **[Setup]**: General application metadata and output configuration.
- **[Languages]**: Inclusion of translation files.
- **[CustomMessages]**: Localized strings for shortcuts and descriptions.
- **[Files]**: Defines the source files from the build output to be included in the installer.
- **[Icons]**: Start menu and desktop shortcut definitions.
- **[UninstallDelete]**: Ensures local app data is cleaned up during uninstallation.

# Windows Installer Setup

This directory contains the Inno Setup script for creating a Windows installer for the WHPH application.

## Files

- `installer.iss` - Inno Setup script file that defines the installer configuration

## Installer Features

- **Automatic installation** with modern wizard interface
- **Multi-language support** (English and Turkish)
- **Desktop and quick launch shortcuts** (optional)
- **Uninstaller** included
- **License agreement** display
- **Start menu group** creation
- **Low privileges** installation (no admin rights required)
- **64-bit architecture** support
- **Compressed installation** using LZMA compression

## Build Process

The installer is automatically built during the GitHub Actions CI workflow:

1. Flutter app is built for Windows
2. Inno Setup is downloaded and installed
3. The installer script is compiled to create `whph-setup.exe`
4. Both portable ZIP and installer are uploaded as artifacts
5. Both files are attached to GitHub releases

## Manual Build

To build the installer manually on Windows:

1. Install [Inno Setup](https://jrsoftware.org/isinfo.php)
2. Build the Flutter app: `flutter build windows --release`
3. Compile the installer: `"C:\Program Files (x86)\Inno Setup 6\ISCC.exe" windows\setup-wizard\installer.iss`

The installer will be created at `build\windows\installer\whph-setup.exe`.

## Configuration

The installer script automatically:

- Uses the app version from `pubspec.yaml`
- Includes all files from the Flutter Windows build
- Sets up proper program files installation
- Creates uninstall entries in Windows
- **Detects system language** and displays interface in Turkish or English

## Language Support

The installer supports multiple languages:

- **English** (default)
- **Turkish** (Türkçe)

The installer will automatically detect the system language and display the appropriate interface. Users can also manually select their preferred language during installation.

## Installation Locations

- **Program files**: `%ProgramFiles%\WHPH\`
- **User data**: `%LocalAppData%\WHPH\` (cleaned on uninstall)
- **Start menu**: WHPH group with app and uninstaller shortcuts
- **Desktop**: Optional WHPH shortcut
- **Quick Launch**: Optional WHPH shortcut (Windows 7 and below)

#!/bin/bash

# WHPH Local Build Script for Flatpak
# This script builds the Flutter app locally first, then packages it into a Flatpak
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
FLATPAK_DIR="$SCRIPT_DIR"
APP_ID="me.ahmetcetinkaya.whph"

echo "Building WHPH Flatpak with pre-built Flutter app..."
echo "Project root: $PROJECT_ROOT"
echo "Flatpak directory: $FLATPAK_DIR"

# Check if Flutter is available (using fvm)
if ! fvm flutter --version &> /dev/null; then
    echo "Error: Flutter is not installed or not working properly."
    echo "Please install Flutter and make sure it's available in your PATH."
    exit 1
fi

# Build the Flutter app locally first
echo "Building Flutter Linux app locally..."
cd "$PROJECT_ROOT"
fvm flutter pub get
fvm flutter build linux --release

# Check if build was successful
if [ ! -d "$PROJECT_ROOT/build/linux/x64/release/bundle" ]; then
    echo "Error: Flutter build failed. Bundle directory not found."
    exit 1
fi

echo "Flutter build successful. Creating bundle for Flatpak..."

# Create resized icon for Flatpak (512x512 max)
echo "Creating resized icon..."
if command -v magick &> /dev/null; then
    magick "$PROJECT_ROOT/lib/src/core/domain/shared/assets/images/whph_logo.png" -resize 512x512 "$FLATPAK_DIR/whph_logo_512.png"
elif command -v convert &> /dev/null; then
    convert "$PROJECT_ROOT/lib/src/core/domain/shared/assets/images/whph_logo.png" -resize 512x512 "$FLATPAK_DIR/whph_logo_512.png"
else
    echo "Warning: ImageMagick not found. Using original icon (may cause issues)."
    cp "$PROJECT_ROOT/lib/src/core/domain/shared/assets/images/whph_logo.png" "$FLATPAK_DIR/whph_logo_512.png"
fi

# Download shared modules for libappindicator
echo "Downloading shared modules..."
if [ ! -d "$FLATPAK_DIR/shared-modules" ]; then
    git clone --depth 1 https://github.com/flathub/shared-modules.git "$FLATPAK_DIR/shared-modules"
fi

# Create a minimal Flatpak manifest that just packages the pre-built app
cat > "$FLATPAK_DIR/me.ahmetcetinkaya.whph.simple.yml" << 'EOF'
app-id: me.ahmetcetinkaya.whph
runtime: org.freedesktop.Platform
runtime-version: '24.08'
sdk: org.freedesktop.Sdk
command: whph
separate-locales: false


finish-args:
  # X11 + XShm access for GUI
  - --share=ipc
  - --socket=x11
  - --socket=fallback-x11
  
  # Wayland access
  - --socket=wayland
  
  # Audio access for notifications
  - --socket=pulseaudio
  
  # Network access for sync features
  - --share=network
  
  # File system access
  - --filesystem=home
  - --filesystem=xdg-documents
  - --filesystem=xdg-download
  
  # D-Bus access for desktop integration
  - --talk-name=org.freedesktop.Notifications
  - --talk-name=org.freedesktop.secrets
  - --talk-name=org.gtk.vfs.*
  - --filesystem=xdg-run/gvfsd
  
  # System tray support
  - --talk-name=org.kde.StatusNotifierWatcher
  - --talk-name=org.freedesktop.portal.Desktop
  - --talk-name=org.freedesktop.portal.FileChooser
  
  # Theme access
  - --filesystem=xdg-config/gtk-3.0:ro
  - --filesystem=xdg-config/gtk-4.0:ro
  
  # Device access for app usage tracking (if needed)
  - --device=dri
  
  # App usage tracking permissions
  - --filesystem=/proc:ro
  - --talk-name=org.gnome.Shell
  - --talk-name=org.kde.KWin
  - --talk-name=org.kde.kwin
  - --talk-name=org.freedesktop.DBus
  - --system-talk-name=org.freedesktop.login1
  
  # Window manager tools access (for X11/Wayland detection)
  - --talk-name=org.freedesktop.portal.*

modules:
  - shared-modules/libappindicator/libappindicator-gtk3-12.10.json

  - name: xprop
    buildsystem: simple
    build-commands:
      - mkdir -p /app/bin
      - cp /usr/bin/xprop /app/bin/ || echo "xprop not available in runtime"

  - name: wmctrl  
    buildsystem: simple
    build-commands:
      - mkdir -p /app/bin
      - cp /usr/bin/wmctrl /app/bin/ || echo "wmctrl not available in runtime"

  - name: whph
    buildsystem: simple
    build-commands:
      # Install the pre-built Flutter application
      - mkdir -p /app/bin
      - cp -r flutter-bundle/* /app/
      - ln -sf /app/whph /app/bin/whph
      
      # Install desktop file
      - mkdir -p /app/share/applications
      - cp whph.desktop /app/share/applications/me.ahmetcetinkaya.whph.desktop
      - sed -i 's/Exec=whph/Exec=\/app\/bin\/whph/' /app/share/applications/me.ahmetcetinkaya.whph.desktop
      - sed -i 's/Icon=\${ICON_PATH}/Icon=me.ahmetcetinkaya.whph/' /app/share/applications/me.ahmetcetinkaya.whph.desktop
      
      # Install icon
      - mkdir -p /app/share/icons/hicolor/512x512/apps
      - cp whph_logo.png /app/share/icons/hicolor/512x512/apps/me.ahmetcetinkaya.whph.png
      
      # Install metainfo
      - mkdir -p /app/share/metainfo
      - cp me.ahmetcetinkaya.whph.metainfo.xml /app/share/metainfo/
    
    sources:
      - type: dir
        path: bundle-staging
        dest: flutter-bundle
        
      - type: file
        path: ../whph.desktop
        dest-filename: whph.desktop
        
      - type: file
        path: whph_logo_512.png
        dest-filename: whph_logo.png
        
      - type: file
        path: me.ahmetcetinkaya.whph.metainfo.xml
        dest-filename: me.ahmetcetinkaya.whph.metainfo.xml
EOF

# Create bundle staging directory
echo "Preparing bundle staging directory..."
rm -rf "$FLATPAK_DIR/bundle-staging"
mkdir -p "$FLATPAK_DIR/bundle-staging"
cp -r "$PROJECT_ROOT/build/linux/x64/release/bundle"/* "$FLATPAK_DIR/bundle-staging/"

# Ensure required runtimes are installed
echo "Ensuring required runtimes are installed..."
flatpak install -y --user flathub org.freedesktop.Platform//24.08 || true
flatpak install -y --user flathub org.freedesktop.Sdk//24.08 || true

# Clean any previous builds
echo "Cleaning previous builds..."
rm -rf "$FLATPAK_DIR/build-dir"
rm -rf "$FLATPAK_DIR/repo"
rm -f "$FLATPAK_DIR/$APP_ID.flatpak"

# Build the Flatpak
echo "Building Flatpak..."
cd "$FLATPAK_DIR"

flatpak-builder \
    --force-clean \
    --disable-rofiles-fuse \
    --user \
    --install-deps-from=flathub \
    build-dir \
    "$APP_ID.simple.yml"

echo "Creating Flatpak bundle..."
flatpak build-export repo build-dir
flatpak build-bundle repo "$APP_ID.flatpak" "$APP_ID"

# Clean up staging directory and temporary files
rm -rf "$FLATPAK_DIR/bundle-staging"
rm -rf "$FLATPAK_DIR/shared-modules"
rm -f "$FLATPAK_DIR/whph_logo_512.png"
rm -f "$FLATPAK_DIR/me.ahmetcetinkaya.whph.simple.yml"

echo ""
echo "✅ Flatpak build completed successfully!"
echo "📦 Flatpak bundle created: $FLATPAK_DIR/$APP_ID.flatpak"
echo ""
echo "To install the Flatpak:"
echo "  flatpak install --user $APP_ID.flatpak"
echo ""
echo "To run the application:"
echo "  flatpak run $APP_ID"
echo ""
echo "To uninstall:"
echo "  flatpak uninstall --user $APP_ID"
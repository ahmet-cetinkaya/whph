{
  description = "WHPH - Work Hard Play Hard - Development environment";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
          config = {
            allowUnfree = true;
            permittedInsecurePackages = [ ];
            android_sdk.acceptLicense = true;
          };
        };

        # Native dependencies for Linux desktop development
        linuxBuildInputs = with pkgs; [
          # GTK and GLib
          gtk3
          glib
          libgee

          # Build tools
          cmake
          ninja
          pkg-config
          clang-tools
          clang

          # X11 for window detection (using new non-deprecated paths)
          libx11
          libxtst
          xprop
          xwininfo
          libsm
          libice
          libxext
          libxrandr
          libxcomposite
          libxdamage
          libxfixes
          libxrender
          libxcursor
          libxinerama
          libxi

          # OpenGL support
          libglvnd

          # Base libraries
          zlib

          # Wayland support
          wayland
          wayland-protocols

          # Additional runtime dependencies
          libsecret
          jsoncpp
          sqlite
          at-spi2-core
          pango
          cairo
          gdk-pixbuf
          harfbuzz
          libnotify
          libayatana-appindicator
          libdbusmenu

          # Additional dependencies for Flutter Linux
          libepoxy
          fontconfig
          sysprof
          libdrm
          libxkbcommon

          # GStreamer for multimedia
          gst_all_1.gstreamer
          gst_all_1.gst-plugins-base
          gst_all_1.gst-plugins-good
          gst_all_1.gst-plugins-bad
          gst_all_1.gst-plugins-ugly
          gst_all_1.gst-libav
          gst_all_1.gst-devtools
          gst_all_1.gst-vaapi

          # Command-line utilities for window detection
          wmctrl
          xdotool
          jq
          zenity

          # Archive tools
          zip
          unzip
        ];

        # Development tools
        devTools = with pkgs; [
          # Flutter Version Manager
          fvm

          # Code formatting
          prettier
          shfmt
          clang-tools

          # Git tools
          git
          gh

          # File utilities
          fd
          ripgrep
          jq

          # Node for some scripts
          nodejs_22

          # Go for shfmt if needed
          go

          # Other utilities
          bat
          eza
          htop
        ];

        # Shell hook to set up environment
        shellHook = ''
          # Project paths
          export PROJECT_ROOT="$(pwd)"
          export SRC_DIR="$PROJECT_ROOT/src"

          # Setup FVM for Flutter version management
          if command -v fvm &> /dev/null && [ -f "$SRC_DIR/.fvmrc" ]; then
            cd "$SRC_DIR" || exit 1
            fvm use 3.32.0 --force 2>/dev/null || true
            export PATH="$SRC_DIR/.fvm/flutter_sdk/bin:$PATH"
            cd "$PROJECT_ROOT" || exit 1
          fi

          # Add scripts to PATH
          export PATH="$PROJECT_ROOT/scripts:$PATH"

          # Development mode flags
          export DEMO_MODE="true"

          # CMake install prefix (avoid needing root)
          # Removed export CMAKE_INSTALL_PREFIX to let Flutter use the default bundle path

          # PKG_CONFIG_PATH is automatically handled by Nix mkShell


          # Library path for runtime
          export LD_LIBRARY_PATH="${pkgs.lib.makeLibraryPath linuxBuildInputs}:$LD_LIBRARY_PATH"

          # Dart build configuration
          export DART_WARN_ON_DART_2_XX_BREAKING_CHANGES=false

          # Flutter build cache
          export PUB_CACHE="$HOME/.pub-cache"

          # GStreamer plugins path
          export GST_PLUGIN_SYSTEM_PATH_1_0="${pkgs.gst_all_1.gst-plugins-base}/lib/gstreamer-1.0:${pkgs.gst_all_1.gst-plugins-good}/lib/gstreamer-1.0:${pkgs.gst_all_1.gst-plugins-bad}/lib/gstreamer-1.0:${pkgs.gst_all_1.gst-plugins-ugly}/lib/gstreamer-1.0"
        '';

      in {
        # Development shell
        devShells.default = pkgs.mkShell {
          name = "whph-dev";

          buildInputs = linuxBuildInputs ++ devTools;

          inherit shellHook;

          shell = pkgs.bash;
        };
      }
    );
}

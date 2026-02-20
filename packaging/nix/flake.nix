{
  description = "A comprehensive productivity app designed to help you manage tasks, develop new habits, and optimize your time.";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };
        
        pname = "whph";
        version = "0.22.1";

        # Source assets from the project
        desktopTemplate = ../../src/linux/whph.desktop.in;
        iconFile = ../../src/lib/core/domain/shared/assets/images/whph-512.png;
        
        src = pkgs.fetchurl {
          url = "https://github.com/ahmet-cetinkaya/whph/releases/download/v${version}/whph-v${version}-linux.tar.gz";
          hash = "0rk43i6krwmn5z7lsdb3rfi09ndrdy7hh294sigfn0q1i0bsqcpd";
        };
      in {
        packages.default = pkgs.stdenv.mkDerivation {
          inherit pname version src;

          nativeBuildInputs = [
            pkgs.autoPatchelfHook
            pkgs.wrapGAppsHook3
          ];

          buildInputs = [
            pkgs.gtk3
            pkgs.glib
            pkgs.libgee
            pkgs.libsecret
            pkgs.jsoncpp
            pkgs.libayatana-appindicator
            pkgs.libdbusmenu
            pkgs.sqlite
            pkgs.at-spi2-core
            pkgs.pango
            pkgs.cairo
            pkgs.gdk-pixbuf
            pkgs.harfbuzz
            pkgs.libX11
            pkgs.libnotify
            pkgs.zenity
            pkgs.wmctrl
            pkgs.xdotool
            pkgs.jq
            pkgs.xprop
          ] ++ (with pkgs; [
            gst_all_1.gstreamer
            gst_all_1.gst-plugins-base
            gst_all_1.gst-plugins-good
          ]);

          unpackPhase = ''
            mkdir -p source
            tar -xzf $src -C source --strip-components=1 || tar -xzf $src -C source
          '';

          installPhase = ''
            mkdir -p $out/bin $out/lib/whph-app $out/share/applications $out/share/icons/hicolor/512x512/apps
            
            cp -r source/* $out/lib/whph-app/
            ln -s $out/lib/whph-app/whph $out/bin/whph
            
            # Install branding and desktop file from source assets
            install -Dm644 ${iconFile} $out/share/icons/hicolor/512x512/apps/me.ahmetcetinkaya.whph.png
            
            # Specialize the desktop file from template
            substitute ${desktopTemplate} $out/share/applications/me.ahmetcetinkaya.whph.desktop \
              --replace "@APP_VERSION@" "${version}" \
              --replace "@EXEC_PATH@" "$out/bin/whph" \
              --replace "@ICON_PATH@" "me.ahmetcetinkaya.whph"
          '';

          # Add runtime dependencies to PATH
          preFixup = ''
            gappsWrapperArgs+=(
              --prefix PATH : "${pkgs.lib.makeBinPath [
                pkgs.zenity
                pkgs.wmctrl
                pkgs.xdotool
                pkgs.jq
                pkgs.xprop
              ]}"
            )
          '';

          meta = with pkgs.lib; {
            description = "A comprehensive productivity app designed to help you manage tasks, develop new habits, and optimize your time.";
            homepage = "https://whph.ahmetcetinkaya.me";
            license = licenses.gpl3;
            platforms = [ "x86_64-linux" ];
            mainProgram = "whph";
          };
        };

        apps.default = flake-utils.lib.mkApp {
          drv = self.packages.${system}.default;
        };
      }
    );
}

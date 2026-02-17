# NixOS Packaging

A comprehensive productivity app designed to help you manage tasks, develop new habits, and optimize your time.

WHPH is available on NixOS via a Nix Flake. This document provides instructions for using, developing, and building the WHPH flake locally.

## Prerequisites

- Nix package manager with flakes enabled.

## Usage

### Run the application

You can run the application directly from the flake without installing it:

```bash
nix run .#whph
```

### Build the application

To build the application and produce a result in `result/`:

```bash
nix build .#whph
```

### Development Shell

To enter a development shell with all dependencies available:

```bash
nix develop
```

## Integration into NixOS

To add WHPH to your NixOS configuration, add it to your `flake.nix` inputs:

```nix
inputs = {
  nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  whph.url = "github:ahmet-cetinkaya/whph?dir=packaging/nix";
};
```

Then, add it to your `environment.systemPackages` in `configuration.nix`:

```nix
outputs = { self, nixpkgs, whph, ... }: {
  nixosConfigurations.your-hostname = nixpkgs.lib.nixosSystem {
    modules = [
      ./configuration.nix
      ({ pkgs, ... }: {
        environment.systemPackages = [
          whph.packages.${pkgs.system}.default
        ];
      })
    ];
  };
};
```

## Maintenance

The `flake.nix` uses `autoPubspecLock` to manage Dart dependencies. Ensure `src/pubspec.lock` is up-to-date.

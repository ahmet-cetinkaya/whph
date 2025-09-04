# WHPH Project Structure

This document provides a comprehensive overview of the WHPH (Work Hard Play Hard) project structure and organization. WHPH is a comprehensive productivity app designed to help you manage tasks, develop new habits, and optimize your time.

## Root Directory Overview

The project follows a standard Flutter application structure with additional platform-specific directories and custom organization:

```
whph-2/
├── android/                    # Android platform-specific code and configuration
├── build/                      # Build artifacts and generated files
├── docs/                       # Project documentation
├── fastlane/                   # Fastlane configuration for CI/CD
├── ios/                        # iOS platform-specific code (currently unused)
├── lib/                        # Main Dart source code
├── linux/                      # Linux platform-specific code
├── macos/                      # macOS platform-specific code (currently unused)
├── scripts/                    # Build and utility scripts
├── snap/                       # Snap package configuration
├── test/                       # Test files
├── web/                        # Web platform assets
├── windows/                    # Windows platform-specific code
├── pubspec.yaml               # Flutter project configuration
├── README.md                  # Project overview and installation guide
├── CHANGELOG.md               # Version history and changes
├── LICENSE                    # Project license
└── PRIVACY_POLICY.md          # Privacy policy document
```

## Source Code Organization (`src/lib/` directory)

The `src/lib/` directory contains the main Dart source code organized using Clean Architecture principles:

```
lib/
├── corePackages/              # External core packages and submodules
│   └── acore/                 # Core Flutter utilities submodule
├── src/                       # Main application source code
│   ├── core/                  # Core business logic and domain
│   ├── infrastructure/        # External concerns and platform-specific code
│   └── presentation/          # UI and API layers
├── main.dart                  # Application entry point
└── main.mapper.g.dart         # Generated mapper code
```

### Core Layer (`src/lib/core/`)

Contains the business logic and domain models:

```
src/core/
├── application/               # Application services and use cases
├── domain/                    # Domain entities, value objects, and business rules
└── shared/                    # Shared core utilities and abstractions
```

### Infrastructure Layer (`src/lib/infrastructure/`)

Handles external concerns and platform-specific implementations:

```
src/infrastructure/
├── android/                   # Android-specific implementations
├── desktop/                   # Desktop-specific implementations
├── linux/                     # Linux-specific implementations
├── mobile/                    # Mobile-specific implementations
├── persistence/               # Database and storage implementations
├── shared/                    # Shared infrastructure utilities
├── windows/                   # Windows-specific implementations
└── infrastructure_container.dart  # Dependency injection container
```

### Presentation Layer (`src/lib/presentation/`)

Contains UI components and API controllers:

```
src/presentation/
├── api/                       # API controllers and endpoints
├── ui/                        # User interface components
│   ├── features/              # Feature-specific UI components
│   └── shared/                # Shared UI components and utilities
└── ui_presentation_container.dart  # UI dependency injection
```

## Documentation Structure (`docs/` folder)

The documentation is organized to help contributors and users:

```
docs/
├── CONTRIBUTING.md            # Contribution guidelines and development setup
├── LINUX-DEPENDENCIES.md     # Linux system dependencies guide
├── PROJECT-STRUCTURE.md      # This document
└── screenshots/               # Application screenshots
    ├── mobile_01.png          # Mobile interface screenshots
    ├── mobile_02.png
    └── ...                    # Additional screenshots
```

## Platform-Specific Directories

### Android (`android/`)

Contains Android-specific configuration and build files:

```
android/
├── app/                       # Android app module
├── fdroid/                    # F-Droid repository submodule
├── gradle/                    # Gradle wrapper files
├── build.gradle              # Android build configuration
├── gradle.properties         # Gradle properties
├── local.properties          # Local Android SDK configuration
└── settings.gradle           # Gradle settings
```

### Windows (`windows/`)

Windows platform implementation and setup:

```
windows/
├── flutter/                   # Flutter Windows engine files
├── runner/                    # Windows application runner
├── setup-wizard/              # Inno Setup installer configuration
│   ├── installer.iss          # Inno Setup script
│   └── README.md              # Setup wizard documentation
└── CMakeLists.txt            # CMake build configuration
```

### Linux (`linux/`)

Linux platform implementation:

```
linux/
├── flutter/                   # Flutter Linux engine files
├── main.cc                    # Linux application entry point
├── my_application.cc          # Application implementation
├── my_application.h           # Application header
├── whph.desktop              # Desktop entry file
├── window_detector.cpp        # Window detection functionality
├── window_detector.h          # Window detection header
└── CMakeLists.txt            # CMake build configuration
```

## Build and Configuration Files

### Core Configuration

- **`pubspec.yaml`** - Flutter project configuration, dependencies, and custom scripts
- **`pubspec.lock`** - Locked dependency versions
- **`analysis_options.yaml`** - Dart/Flutter linting rules
- **`build.yaml`** - Build runner configuration
- **`devtools_options.yaml`** - Flutter DevTools configuration
- **`icons_launcher.yaml`** - App icon generation configuration

### Version Control

- **`.gitignore`** - Git ignore patterns
- **`.gitmodules`** - Git submodule configuration
- **`.metadata`** - Flutter project metadata

### Development Tools

- **`.fvmrc`** - Flutter Version Management configuration
- **`.vscode/`** - Visual Studio Code settings
- **`.github/`** - GitHub Actions workflows and templates

## F-Droid Integration (`android/fdroid/` submodule)

The F-Droid integration is handled through a Git submodule:

```
android/fdroid/                # F-Droid repository submodule
├── metadata/                  # App metadata for F-Droid
├── config/                    # F-Droid server configuration
├── tools/                     # F-Droid build and maintenance tools
├── templates/                 # Build templates
├── srclibs/                   # Source library definitions
└── config.yml                # Main F-Droid configuration
```

This submodule points to a separate GitLab repository (`ahmet-cetinkaya/fdroid-data`) on the `me.ahmetcetinkaya.whph` branch, containing F-Droid-specific metadata and build configurations.

## Core Packages and Submodules (`src/lib/corePackages/acore/`)

The project includes the `acore-flutter` package as a Git submodule:

```
lib/corePackages/acore/        # acore-flutter submodule
├── lib/                       # Core package source code
│   └── src/                   # Organized by functionality
│       ├── components/        # Reusable UI components
│       ├── dependency_injection/  # DI container and abstractions
│       ├── errors/            # Error handling utilities
│       ├── file/              # File system abstractions
│       ├── logging/           # Logging utilities
│       ├── mapper/            # Data mapping utilities
│       ├── queries/           # Query models and helpers
│       ├── repository/        # Repository pattern implementations
│       ├── sounds/            # Sound utilities
│       ├── storage/           # Storage abstractions
│       ├── time/              # Date/time utilities
│       └── utils/             # General utilities
├── pubspec.yaml              # Package configuration
└── README.md                 # Package documentation
```

This submodule provides reusable Flutter components, utilities, and abstractions used throughout the WHPH application.

## Scripts Directory (`scripts/`)

Contains utility scripts for development and build processes:

```
scripts/
├── clean.sh                   # Clean build artifacts and caches
├── create_changelog.sh        # Generate changelog from git history
├── get_flutter_version.sh     # Get current Flutter version
├── test_ci_fdroid.sh         # Test F-Droid CI pipeline
└── version_bump.sh           # Bump version numbers
```

These scripts are integrated with the `pubspec.yaml` scripts section and can be run using the `rps` package.

## Key Files Explanation

### Application Entry Points

- **`src/lib/main.dart`** - Main application entry point, sets up global error handling, dependency injection, and launches the app
- **`src/lib/presentation/ui/app.dart`** - Main app widget with routing and theme configuration

### Dependency Injection

- **`src/lib/infrastructure/infrastructure_container.dart`** - Infrastructure layer DI container
- **`src/lib/presentation/ui/ui_presentation_container.dart`** - Presentation layer DI container

### Platform Integration

- **`linux/main.cc`** - Linux application entry point with window detection
- **`windows/runner/main.cpp`** - Windows application entry point
- **`android/app/src/main/`** - Android application configuration

### Build Configuration

- **`pubspec.yaml`** - Defines dependencies, assets, and custom build scripts
- **`build.yaml`** - Configures code generation (Drift, JSON mapping)
- **Platform CMakeLists.txt** - Native build configuration for desktop platforms

### Development Tools

- **`.fvmrc`** - Specifies Flutter version (3.32.0) for consistent development
- **`analysis_options.yaml`** - Dart linting and analysis rules
- **GitHub Actions workflows** - Automated testing and building for all platforms

## Architecture Overview

The project follows Clean Architecture principles:

1. **Domain Layer** (`src/lib/core/domain/`) - Business entities and rules
2. **Application Layer** (`src/lib/core/application/`) - Use cases and application services
3. **Infrastructure Layer** (`src/lib/infrastructure/`) - External concerns (database, file system, platform APIs)
4. **Presentation Layer** (`src/lib/presentation/`) - UI components and API controllers

This structure ensures separation of concerns, testability, and maintainability while supporting multiple platforms (Android, Windows, Linux) with platform-specific optimizations.

## Getting Started

For new contributors:

1. Read `docs/CONTRIBUTING.md` for development setup
2. Check `docs/LINUX-DEPENDENCIES.md` if developing on Linux
3. Review the `pubspec.yaml` scripts section for available commands
4. Explore the `src/lib/` directory structure to understand the codebase organization

The project uses modern Flutter development practices with comprehensive tooling for building, testing, and deploying across multiple platforms.
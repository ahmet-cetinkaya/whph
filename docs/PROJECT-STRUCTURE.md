# WHPH Project Structure

This document provides a comprehensive overview of the WHPH (Work Hard Play Hard) project structure and organization. WHPH is a comprehensive productivity app designed to help you manage tasks, develop new habits, and optimize your time.

## Root Directory Overview

The project follows a standard Flutter application structure with additional platform-specific directories and custom organization:

```text
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
```text

## Source Code Organization (`src/lib/` directory)

The `src/lib/` directory contains the main Dart source code organized using Clean Architecture principles:

```text
src/lib/
├── corePackages/              # External core packages and submodules
│   └── acore/                 # Core Flutter utilities submodule
├── core/                      # Core business logic and domain
│   ├── application/           # Application services and use cases
│   └── domain/                # Domain entities and business rules
├── infrastructure/            # External concerns and platform-specific code
├── presentation/              # UI and API layers
├── main.dart                  # Application entry point
└── main.mapper.g.dart         # Generated mapper code
```

### Core Layer (`src/lib/core/`)

Contains the business logic and domain models:

```text
core/
├── application/               # Application services and use cases
│   ├── features/              # Feature-specific commands, queries, and services
│   │   ├── app_usages/        # App usage tracking
│   │   ├── demo/              # Demo data generation
│   │   ├── habits/            # Habit management
│   │   ├── notes/             # Notes feature
│   │   ├── settings/          # Application settings
│   │   ├── sync/              # Data synchronization (modular services)
│   │   ├── tags/              # Tag management
│   │   ├── tasks/             # Task management
│   │   └── widget/            # Home widget support
│   └── shared/                # Shared application utilities
└── domain/                    # Domain entities, value objects, and business rules
    ├── features/              # Feature-specific domain models
    └── shared/                # Shared domain utilities
```

### Infrastructure Layer (`src/lib/infrastructure/`)

Handles external concerns and platform-specific implementations:

```text
infrastructure/
├── android/                   # Android-specific implementations
├── desktop/                   # Desktop-specific implementations (shared)
├── linux/                     # Linux-specific implementations
│   └── features/setup/        # Linux setup with modular services
│       └── services/          # Firewall, Desktop, KDE, Update services
├── mobile/                    # Mobile-specific implementations
├── persistence/               # Database and storage implementations
├── shared/                    # Shared infrastructure utilities
├── windows/                   # Windows-specific implementations
│   └── features/setup/        # Windows setup with modular services
│       └── services/          # Firewall, Elevation, Shortcut, Update services
└── infrastructure_container.dart  # Dependency injection container
```

### Presentation Layer (`src/lib/presentation/`)

Contains UI components and API controllers:

```text
presentation/
├── api/                       # API controllers and endpoints
├── ui/                        # User interface components
│   ├── features/              # Feature-specific UI components
│   │   ├── habits/            # Habit UI (modular calendar, details)
│   │   ├── tasks/             # Task UI (modular recurrence, quick add)
│   │   ├── sync/              # Sync UI (modular device management)
│   │   └── ...                # Other features
│   └── shared/                # Shared UI components and utilities
│       └── components/        # Modular UI components (tour, date picker)
└── ui_presentation_container.dart  # UI dependency injection
```

## Modular Architecture Patterns (PR #156)

The refactoring introduces consistent modular patterns throughout the codebase:

### Service Modularization

Large services are broken into smaller, focused helper classes:

```text
# Example: Sync Communication Service
sync_communication_service/
├── sync_communication_service.dart    # Main orchestrator
└── helpers/
    ├── sync_dto_serializer.dart       # DTO-to-JSON conversion
    └── sync_message_serializer.dart   # Message serialization
```

### Command Handler Modularization

Complex command handlers delegate to specialized components:

```text
# Example: Paginated Sync Command
paginated_sync_command/
├── paginated_sync_command.dart        # Main handler
└── helpers/
    ├── sync_incoming_handler.dart     # Incoming data processing
    ├── sync_outgoing_handler.dart     # Outgoing data orchestration
    ├── sync_device_orchestrator.dart  # Device coordination
    ├── sync_page_accumulator.dart     # Page aggregation
    ├── sync_progress_tracker.dart     # Progress tracking
    └── sync_response_builder.dart     # Response construction
```

### Platform Service Modularization

Platform-specific code uses interface segregation:

```text
# Example: Linux Setup Services
linux/features/setup/
├── linux_setup_service.dart           # Main coordinator
├── services/
│   ├── abstraction/                   # Service interfaces
│   │   ├── i_linux_firewall_service.dart
│   │   ├── i_linux_desktop_service.dart
│   │   ├── i_linux_kde_service.dart
│   │   └── i_linux_update_service.dart
│   ├── linux_firewall_service.dart    # UFW integration
│   ├── linux_desktop_service.dart     # Desktop file management
│   ├── linux_kde_service.dart         # KDE Plasma integration
│   └── linux_update_service.dart      # Update management
└── exceptions/
    └── linux_firewall_rule_exception.dart
```

### UI Component Modularization

Complex widgets extract logic into controllers and helpers:

```text
# Example: Task Recurrence Selector
components/task_recurrence_selector/
├── task_recurrence_selector.dart      # Main widget
├── task_recurrence_controller.dart    # State management
└── helpers/
    ├── recurrence_date_helper.dart    # Date calculations
    └── recurrence_ui_helper.dart      # UI utilities
```

### Benefits of This Pattern

1. **Single Responsibility**: Each module has one clear purpose
2. **Testability**: Small modules are easier to unit test in isolation
3. **Maintainability**: Changes to one concern don't affect others
4. **Discoverability**: Related code is organized together
5. **Reusability**: Helpers can be reused across features

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

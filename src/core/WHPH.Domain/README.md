# WHPH.Domain

Domain layer for the WHPH (Work Hard Play Hard) productivity app.

## Purpose

This package contains the business entities and domain rules following Clean Architecture principles. The domain layer should have no dependencies on the application or infrastructure layers.

## Structure

```
lib/
├── features/         # Feature-specific domain models
│   ├── app_usages/
│   ├── habits/
│   ├── notes/
│   ├── settings/
│   ├── sync/
│   ├── tags/
│   └── tasks/
└── shared/           # Shared domain elements
    ├── constants/
    ├── utils/
    └── assets/
        └── images/
```

## Dependencies

- **acore**: Core utilities from the acore-flutter package
- **dart_json_mapper**: JSON serialization support
- **equatable**: Value equality comparisons
- **meta**: Dart annotations
- **flutter**: (Technical Debt) Some domain entities currently depend on Flutter types (e.g., Color, ThemeData). These should be refactored to be framework-agnostic.

## Technical Debt Notes

1. **Flutter Dependency**: The domain layer should not depend on Flutter. The following files need refactoring:
   - `shared/constants/app_theme.dart` - Uses `ThemeData` from Flutter
   - `features/habits/habit.dart` - Uses `Color` from Flutter

2. **Images**: Domain layer images should be moved to the presentation layer.

## Usage

In the Flutter app, add this package to `pubspec.yaml`:

```yaml
dependencies:
  whph_domain:
    path: ../../../core/WHPH.Domain
```

Then import domain entities:

```dart
import 'package:whph_domain/features/tasks/task.dart';
import 'package:whph_domain/features/habits/habit.dart';
```

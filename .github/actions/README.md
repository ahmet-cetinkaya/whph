# Reusable GitHub Actions

This directory contains composite actions that are shared across multiple workflows to reduce code duplication and improve maintainability.

## Available Actions

### 1. setup-repository (Initialize Submodules)

**Purpose**: Initializes required submodules for the project (specifically the acore submodule).

**Note**: This action should be used after a standard `actions/checkout@v4` step.

**Usage**:

```yaml
- name: Checkout code
  uses: actions/checkout@v4
  with:
    submodules: recursive

- name: Initialize Submodules
  uses: ./.github/actions/setup-repository
```

### 2. setup-fvm

**Purpose**: Sets up Flutter using FVM (Flutter Version Management) with caching.

**Inputs**:

- `cache-key-suffix` (optional): Additional suffix for cache key

**Outputs**:

- `flutter-version`: The Flutter version that was installed
- `cache-hit`: Whether the cache was hit

**Usage**:

```yaml
- name: Setup Flutter with FVM
  uses: ./.github/actions/setup-fvm
  with:
    cache-key-suffix: 'android'
```

### 3. install-flutter-deps

**Purpose**: Installs Flutter dependencies and sets up pub cache.

**Inputs**:

- `enable-platform` (optional): Platform to enable (e.g., 'windows-desktop')

**Usage**:

```yaml
- name: Install Flutter Dependencies
  uses: ./.github/actions/install-flutter-deps
  with:
    enable-platform: windows-desktop
```

### 4. get-app-version

**Purpose**: Extracts application version from pubspec.yaml.

**Outputs**:

- `version`: The full application version (e.g., "0.11.1+49")
- `version-number`: The version number without build number (e.g., "0.11.1")
- `build-number`: The build number (e.g., "49")

**Usage**:

```yaml
- name: Get application version
  id: app_version
  uses: ./.github/actions/get-app-version

- name: Use version
  run: echo "Version is ${{ steps.app_version.outputs.version }}"
```

### 5. upload-build-artifact

**Purpose**: Uploads build artifacts with consistent naming and versioning.

**Inputs**:

- `artifact-name` (required): Name of the artifact (e.g., 'android', 'linux', 'windows-portable')
- `artifact-path` (required): Path to the artifact files
- `app-version` (required): Application version for naming
- `compression-level` (optional): Compression level for the artifact (default: '6')
- `if-no-files-found` (optional): What to do if no files are found (default: 'error')

**Usage**:

```yaml
- name: Upload build artifact
  uses: ./.github/actions/upload-build-artifact
  with:
    artifact-name: android
    artifact-path: build/app/outputs/flutter-apk/app-release.apk
    app-version: ${{ steps.app_version.outputs.version }}
    compression-level: '0'
```

## Benefits of Refactoring

1. **Reduced Code Duplication**: Common patterns are now centralized in reusable actions
2. **Improved Maintainability**: Changes to common functionality only need to be made in one place
3. **Consistency**: All workflows use the same standardized steps for common operations
4. **Better Testing**: Composite actions can be tested independently
5. **Easier Updates**: Version updates and improvements can be applied across all workflows simultaneously

## Workflow Structure

The refactored workflows now follow this pattern:

1. **Setup Repository**: Check out code and initialize submodules
2. **Setup Flutter**: Install Flutter using FVM with caching
3. **Install Dependencies**: Install Flutter dependencies with platform-specific configuration
4. **Platform-specific Setup**: Install platform-specific tools and dependencies
5. **Build**: Execute the build process
6. **Get Version**: Extract application version
7. **Upload Artifacts**: Upload build artifacts with consistent naming

This structure ensures consistency across all platform-specific CI workflows while keeping platform-specific logic where it belongs.

# GitHub Workflows Documentation

This document provides essential documentation for the GitHub Actions workflows used in the WHPH project for automated builds, releases, and deployment.

## Overview

The WHPH project uses GitHub Actions for CI/CD automation:
- **Multi-platform builds** (Android, Linux, Windows)
- **Automated releases** with version control
- **Google Play Store deployment** with staged rollouts
- **Artifact management** and distribution

## CI/CD Pipelines

### Flutter CI - Android

**File:** `.github/workflows/flutter-ci.android.yml`

**Purpose:** Builds Android APK for version tags and manual triggers.

**Triggers:**
- `workflow_dispatch` - Manual workflow run
- `push` on tags matching `v*.*.*`

**Outputs:** `whph-v{version}-android.apk`

**Requirements:**
- `KEYSTORE_BASE64` - Base64 encoded keystore file
- `KEYSTORE_PASSWORD` - Keystore decryption password
- `KEY_PASSWORD` - Signing key password
- `KEY_ALIAS` - Android signing key alias

### Flutter CI - Linux

**File:** `.github/workflows/flutter-ci.linux.yml`

**Purpose:** Builds Linux portable bundle for version tags and manual triggers.

**Triggers:**
- `workflow_dispatch` - Manual workflow run
- `push` on tags matching `v*.*.*`

**Dependencies:** GTK, cmake, ninja-build, clang, and system libraries

**Outputs:** `whph-v{version}-linux`

### Flutter CI - Windows

**File:** `.github/workflows/flutter-ci.windows.yml`

**Purpose:** Builds Windows portable and installer packages.

**Triggers:**
- `workflow_dispatch` - Manual workflow run
- `push` on tags matching `v*.*.*`

**Features:**
- Release and Profile build modes with fallback
- Inno Setup installer creation
- Workarounds for Windows AOT compilation issues

**Outputs:**
- `whph-v{version}-windows-portable`
- `whph-v{version}-windows-installer`

## Release Management

### Release All Platforms

**File:** `.github/workflows/release.yml`

**Purpose:** Orchestrates multi-platform releases after all CI workflows complete.

**Triggers:**
- `workflow_dispatch` - Manual release trigger
- `workflow_run` after successful completion of all platform CI workflows

**Process:**
1. Validates all CI workflows completed successfully
2. Downloads build artifacts from all platforms
3. Creates GitHub release with consistent naming
4. Generates release notes and installation instructions

**Release Assets:**
- Android APK
- Linux tar.gz archive
- Windows portable zip
- Windows installer

## Google Play Store Deployment

### Google Play Store Deployment

**File:** `.github/workflows/play-store-deploy.yml`

**Purpose:** Manual deployment to Google Play Store tracks.

**Inputs:**
- `track` - Deployment track (internal, alpha, beta, production)
- `promote` - Boolean flag for promotion from previous track
- `rollout_percentage` - Production rollout percentage
- `update_metadata` - Boolean flag to update store metadata

### Google Play Store Post-Release Deployment

**File:** `.github/workflows/play-store-post-release.yml`

**Purpose:** Automatic deployment to Google Play Internal Testing after GitHub release.

**Features:**
- Repository health checks
- Enhanced build validation
- Comprehensive debugging information
- Post-deployment summary with next steps

### Google Play Store Rollout Management

**File:** `.github/workflows/play-store-rollout.yml`

**Purpose:** Manual management of production rollout percentages.

**Inputs:**
- `action` - Rollout action (increase, halt, resume, full)
- `track` - Target track (production only)

**Actions:**
- Increase rollout percentage
- Halt current rollout
- Resume halted rollout
- Deploy full rollout (100%)

## Composite Actions

### Setup Flutter with FVM

**File:** `.github/actions/setup-fvm/action.yml`

**Purpose:** Sets up Flutter using FVM with intelligent caching.

**Features:**
- Cross-platform support (Unix and Windows)
- Automatic version detection from `src/.fvmrc`
- PATH configuration for FVM and Flutter tools
- Analytics disabled for CI/CD environments

### Get Application Version

**File:** `.github/actions/get-app-version/action.yml`

**Purpose:** Extracts application version from `pubspec.yaml`.

**Outputs:**
- `version` - Full version string (e.g., "1.0.0+65")
- `version-number` - Version number only (e.g., "1.0.0")
- `build-number` - Build number only (e.g., "65")

### Upload Build Artifact

**File:** `.github/actions/upload-build-artifact/action.yml`

**Purpose:** Uploads build artifacts with consistent naming.

**Features:**
- Consistent naming: `whph-v{version}-{artifact-name}`
- Configurable compression levels
- Error handling for missing files

## Fastlane Configuration

**File:** `fastlane/Fastfile`

**Purpose:** Ruby-based automation for Google Play Store deployment.

### Key Lanes

**Deployment:**
- `deploy_internal` - Internal Testing track
- `deploy_alpha` - Alpha track
- `deploy_beta` - Beta track
- `deploy_production` - Production with staged rollout
- `deploy_production_full` - Production with 100% rollout

**Promotion:**
- `promote_to_alpha` - Internal to Alpha
- `promote_to_beta` - Alpha to Beta
- `promote_to_production` - Beta to Production

**Rollout Management:**
- `increase_rollout` - Increase production rollout
- `halt_rollout` - Halt current rollout
- `resume_rollout` - Resume halted rollout

**Environment:** Ruby 3.2 with Bundler for dependency management

## Required Secrets

**Android Signing:**
- `KEYSTORE_BASE64` - Base64 encoded keystore file
- `KEYSTORE_PASSWORD` - Keystore decryption password
- `KEY_PASSWORD` - Signing key password
- `KEY_ALIAS` - Android signing key alias

**Google Play Store:**
- `GOOGLE_PLAY_SERVICE_ACCOUNT_KEY` - Base64 encoded service account JSON

## Trigger Events

### Automatic Triggers

**Version Tags:**
- Pattern: `v*.*.*` (e.g., `v1.0.0`)
- Triggers all platform CI workflows
- Chain: CI → Release → Post-release deployment

### Manual Triggers

**CI Builds:** All platform workflows support manual dispatch
**Deployments:** Play Store deployment with track selection
**Rollout Management:** Production rollout percentage control

## Common Issues & Solutions

**Flutter Build Failures:**
- Check Flutter version in `src/.fvmrc`
- Verify platform-specific dependencies
- Review build logs for missing requirements

**Android Signing Issues:**
- Validate keystore secrets are properly encoded
- Check key alias and password combinations
- Verify keystore file integrity

**Google Play Deployment:**
- Service account key must have proper permissions
- AAB file integrity is validated before deployment
- Metadata updates require proper formatting

## Usage Examples

### Manual CI Build
1. Go to Actions tab in GitHub
2. Select workflow (e.g., "Flutter CI - Android")
3. Click "Run workflow"

### Deploy to Google Play
1. Run "Google Play Store Deployment" workflow
2. Select track (internal/alpha/beta/production)
3. Configure rollout percentage for production
4. Run workflow

### Manage Production Rollout
1. Run "Google Play Store Rollout Management" workflow
2. Select action (increase/halt/resume/full)
3. Execute to control rollout percentage

---

For detailed troubleshooting or questions, review the workflow run logs or create an issue in the repository.
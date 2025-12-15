# Fastlane Metadata for F-Droid

This directory contains metadata used by F-Droid to display app information in their repository.

## Structure

- `metadata/android/en-US/` - English (US) locale metadata
  - `title.txt` - App title displayed in F-Droid
  - `short_description.txt` - Brief description (max 80 characters)
  - `full_description.txt` - Detailed app description (max 4000 characters, HTML allowed)
  - `images/` - App graphics and screenshots
    - `icon.png` - App icon (48x48 to 512x512 px)
    - `phoneScreenshots/` - Mobile screenshots
      - `1.png` to `10.png` - Screenshots in order
  - `changelogs/` - Version-specific changelogs
    - `{versionCode}.txt` - Changelog for specific version (max 500 bytes, plain text)

## Guidelines

1. **Screenshots**: Keep file sizes reasonable for mobile users with limited data plans
2. **Descriptions**: Use basic HTML tags for formatting in `full_description.txt`
3. **Changelogs**: Must correspond exactly to the versionCode in pubspec.yaml
4. **Icon**: Minimum 48x48px, maximum 512x512px

## Updating

When releasing a new version:

1. Add a new changelog file named `{versionCode}.txt` in the changelogs directory
2. Update descriptions if necessary
3. Add new screenshots if the UI has changed significantly

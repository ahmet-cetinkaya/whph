# Google Play Store Deployment Guide

This guide explains how to deploy the WHPH app to the Google Play Store using the automated Fastlane and GitHub Actions workflow.

## Prerequisites

### 1. Google Play Console Setup

1. **Create a Google Play Developer Account**
   - Visit [Google Play Console](https://play.google.com/console)
   - Register as a developer ($25 one-time fee)

2. **Create Application**
   - Create new app with package name: `me.ahmetcetinkaya.whph`
   - Complete store listing information
   - Upload initial screenshots and graphics

3. **Setup Service Account**
   - In Google Play Console, go to **Settings** → **API access**
   - Create a new service account
   - Grant necessary permissions:
     - **Release Manager** - Full access to releases
     - **Store Listing** - Manage store metadata
   - Download the JSON key file

### 2. GitHub Secrets Configuration

Add the following secrets to your GitHub repository:

| Secret Name | Description | How to Get |
| :---------- | :---------- | :--------- |
| `GOOGLE_PLAY_SERVICE_ACCOUNT_KEY` | Base64-encoded service account JSON key | `base64 your-service-account-key.json` |
| `KEYSTORE_BASE64` | Base64-encoded Android keystore file | `base64 src/android/app/whph-release.keystore` |
| `KEYSTORE_PASSWORD` | Keystore password | From your existing keystore |
| `KEY_ALIAS` | Key alias | From your existing keystore |
| `KEY_PASSWORD` | Key password | From your existing keystore |

### 3. Fastlane Setup

The Fastlane configuration is already set up in the `fastlane/` directory:

- `Fastfile` - Contains deployment lanes for different tracks
- `Appfile` - App configuration
- `Gemfile` - Ruby dependencies

## Deployment Tracks

### 1. Internal Testing

- **Purpose**: Early testing with trusted testers
- **Access**: Up to 100 testers via email list
- **Review**: No Google review required
- **Deployment**: Automatic on tag push or manual trigger

### 2. Alpha Testing

- **Purpose**: Closed testing with larger group
- **Access**: Up to 1000 testers via Google Groups or email
- **Review**: Google review required
- **Deployment**: Manual promotion from internal testing

### 3. Beta Testing

- **Purpose**: Open testing or larger closed testing
- **Access**: Unlimited testers via opt-in link
- **Review**: Google review required
- **Deployment**: Manual promotion from alpha testing

### 4. Production

- **Purpose**: Public release
- **Access**: All Google Play users
- **Review**: Google review required
- **Deployment**: Manual promotion from beta testing

## Deployment Methods

### 1. Automatic Post-Release Deployment (Internal Testing)

The deployment sequence is now integrated with the GitHub release workflow:

1. **Tag Push**: `git tag v0.18.0 && git push origin v0.18.0`
2. **CI/CD**: Flutter CI workflows build for all platforms
3. **GitHub Release**: Release workflow creates GitHub release with artifacts
4. **Play Store Deployment**: Automatic deployment to internal testing

This ensures that:

- GitHub releases are created before Play Store deployment
- All platform builds are successful before Play Store deployment
- Internal testing gets the same version as the GitHub release

### 2. Manual Deployment & Promotion

Use the **Google Play Store Deployment** workflow in GitHub Actions for:

1. **Track Promotions**: internal → alpha → beta → production
2. **Emergency Deployments**: Quick fixes or updates
3. **Metadata Updates**: Store listing changes

**Steps**:

1. Go to **Actions** → **Google Play Store Deployment**
2. Click **Run workflow**
3. Choose deployment options:
   - **Track**: internal, alpha, beta, or production
   - **Promote**: Promote from previous track (for alpha/beta/production)
   - **Rollout Percentage**: For production releases (0.1, 0.2, 0.5, 1.0)
   - **Update Metadata**: Update store listing information

### 3. Production Rollout Management

Use the **Google Play Store Rollout Management** workflow to manage production rollouts:

1. Go to **Actions** → **Google Play Store Rollout Management**
2. Click **Run workflow**
3. Choose action:
   - **increase**: Increase rollout percentage (10% → 20% → 50% → 100%)
   - **halt**: Stop the rollout (emergency)
   - **resume**: Resume a halted rollout
   - **full**: Deploy to 100% immediately

## Deployment Workflow

### Standard Release Process

1. **Development & Testing**

   ```bash
   # Make changes and test locally
   rps test
   rps run:demo
   ```

2. **Version Bump**

   ```bash
   rps version:patch  # or version:minor, version:major
   ```

3. **Tag & Push**

   ```bash
   git push && git push --tags
   ```

4. **Automated Release Sequence**
   - **CI/CD**: Flutter CI workflows build for all platforms
   - **GitHub Release**: Release workflow creates GitHub release with artifacts
   - **Play Store Internal Testing**: Automatic deployment to internal testing

5. **Test Internal Release**
   - Test the app thoroughly with internal testers
   - Verify all features work correctly

6. **Promote to Alpha**
   - Use "Google Play Store Deployment" workflow
   - Select "alpha" track with "promote" option
   - Wait for Google review (usually a few hours)

7. **Promote to Beta**
   - Use deployment workflow to promote to beta
   - Gather feedback from beta testers

8. **Production Release**
   - Use deployment workflow for production track
   - Start with 10% rollout
   - Monitor for issues
   - Use "Google Play Store Rollout Management" to gradually increase: 20% → 50% → 100%

### Emergency Rollback

If issues are discovered in production:

1. **Halt Rollout**
   - Use the rollout management workflow to halt deployment
   - This stops new users from getting the update

2. **Fix Issues**
   - Create hotfix branch
   - Test thoroughly
   - Release new version

3. **Resume or Deploy New Version**
   - Either resume the halted rollout (if issues were minor)
   - Or deploy a new version with fixes

## Metadata Management

### Store Listing Information

Store metadata is managed in the `fastlane/metadata/android/` directory:

```text
fastlane/metadata/android/
├── en-US/
│   ├── title.txt              # App title
│   ├── short_description.txt  # Short description (80 chars max)
│   ├── full_description.txt   # Full description (4000 chars max)
│   ├── images/
│   │   ├── icon.png          # App icon
│   │   └── phoneScreenshots/ # Screenshots
│   └── changelogs/
│       ├── 65.txt            # Version 65 changelog
│       └── ...
└── [other locales]/
```text

### Updating Metadata

1. **Update Text Content**
   - Edit files in `fastlane/metadata/android/en-US/`
   - Follow character limits and guidelines

2. **Update Screenshots**
   - Add new screenshots to `images/phoneScreenshots/`
   - Name them sequentially: `1.png`, `2.png`, etc.

3. **Deploy Metadata**
   - Use the deployment workflow with "Update store metadata" enabled
   - Or run locally: `cd fastlane && bundle exec fastlane update_metadata`

### Changelog Management

For each release, create a changelog file:

```bash
# For version 65 (build number from pubspec.yaml)
echo "• Fixed crash on app startup
• Added new habit tracking features
• Improved performance" > fastlane/metadata/android/en-US/changelogs/65.txt
```text

## Local Development

### Running Fastlane Locally

1. **Install Ruby Dependencies**

   ```bash
   cd fastlane
   bundle install
   ```

1. **Setup Environment**

   ```bash
   export GOOGLE_PLAY_SERVICE_ACCOUNT_KEY="./google-play-service-account.json"
   export KEYSTORE_FILE_PATH="../src/android/app/whph-release.keystore"
   export KEYSTORE_PASSWORD="your_keystore_password"
   export KEY_ALIAS="your_key_alias"
   export KEY_PASSWORD="your_key_password"
   ```

2. **Run Lanes**

   ```bash
   cd fastlane
   
   # Deploy to internal testing
   bundle exec fastlane deploy_internal
   
   # Promote to alpha
   bundle exec fastlane promote_to_alpha
   
   # Update metadata
   bundle exec fastlane update_metadata
   ```

### Testing Deployments

Before deploying to production:

1. **Test in Internal Testing**
   - Deploy to internal testing track
   - Test with multiple devices
   - Check all major features

2. **Alpha Testing**
   - Promote to alpha track
   - Test with trusted group
   - Collect feedback

3. **Beta Testing**
   - Promote to beta track
   - Open to larger group
   - Monitor crash reports and feedback

## Troubleshooting

### Common Issues

1. **Authentication Errors**
   - Check that service account JSON key is correctly base64 encoded
   - Verify service account has proper permissions in Google Play Console

2. **Build Failures**
   - Ensure Flutter version matches `.fvmrc`
   - Check that all dependencies are installed
   - Verify keystore configuration

3. **Upload Failures**
   - Check that app bundle is properly signed
   - Verify version code is higher than previous release
   - Ensure metadata meets Google Play requirements

4. **Review Rejections**
   - Check Google Play Console for rejection reasons
   - Fix issues and resubmit
   - Common issues: permissions, content policy, metadata

### Debug Commands

```bash
# Check Fastlane configuration
cd fastlane && bundle exec fastlane lanes

# Test authentication
cd fastlane && bundle exec fastlane run validate_google_play_json_key

# Check current rollout status
cd fastlane && bundle exec fastlane run supply --track production --check_latest
```text

## Best Practices

1. **Version Management**
   - Always increment version code for new releases
   - Use semantic versioning (major.minor.patch)
   - Keep changelogs concise and user-focused

2. **Testing Strategy**
   - Test thoroughly in each track before promotion
   - Use real devices, not just emulators
   - Test edge cases and error conditions

3. **Rollout Strategy**
   - Start with small production rollouts (10%)
   - Monitor crash rates and user feedback
   - Increase rollout gradually

4. **Metadata Quality**
   - Keep descriptions up-to-date
   - Use high-quality screenshots
   - Write clear, user-friendly changelogs

5. **Security**
   - Never commit secrets to repository
   - Use GitHub Secrets for sensitive data
   - Rotate service account keys periodically

## Support

For issues with the deployment process:

1. Check GitHub Actions logs for detailed error messages
2. Review Google Play Console for specific rejection reasons
3. Consult Fastlane documentation at <https://docs.fastlane.tools>
4. Check Google Play Developer API documentation

For app-specific issues or questions about the deployment configuration, create an issue in the repository.

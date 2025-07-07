# PowerShell script to extract application version from pubspec.yaml
# This script is used in Windows CI workflow for consistency

# Extract version from pubspec.yaml (without build number)
try {
    $content = Get-Content 'pubspec.yaml' -ErrorAction Stop
    $versionLine = $content | Select-String 'version: (.*)'
    
    if ($versionLine) {
        $fullVersion = $versionLine.Matches.Groups[1].Value
        $appVersion = $fullVersion.Split('+')[0]
        
        # Validate that we got a version
        if ([string]::IsNullOrEmpty($appVersion)) {
            Write-Host "ERROR: Could not extract version from pubspec.yaml"
            exit 1
        }
        
        # Check if version follows semantic versioning pattern
        if ($appVersion -notmatch '^[0-9]+\.[0-9]+\.[0-9]+$') {
            Write-Host "WARNING: Version '$appVersion' does not follow semantic versioning (x.y.z)"
        }
        
        # Output the version
        Write-Host "APP_VERSION=$appVersion"
        
        # If running in GitHub Actions, set the environment variable
        if ($env:GITHUB_ENV) {
            echo "APP_VERSION=$appVersion" >> $env:GITHUB_ENV
            Write-Host "✅ Set APP_VERSION=$appVersion in GitHub Actions environment"
        } else {
            Write-Host "ℹ️  APP_VERSION=$appVersion (not in GitHub Actions environment)"
        }
    } else {
        Write-Host "ERROR: Could not find version line in pubspec.yaml"
        exit 1
    }
} catch {
    Write-Host "ERROR: Failed to read pubspec.yaml - $($_.Exception.Message)"
    exit 1
}

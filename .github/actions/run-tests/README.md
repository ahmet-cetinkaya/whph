# Run All Tests Action

A comprehensive GitHub Action for running all WHPH Flutter application tests on Linux.

## Usage

### Basic Usage

```yaml
- name: Run All Tests
  uses: ./.github/actions/run-tests
```

### Advanced Usage

```yaml
- name: Run All Tests
  uses: ./.github/actions/run-tests
  with:
    enable-code-coverage: 'true'
    upload-coverage: 'true'
    cache-key-suffix: 'custom-tests'
    run-build-runner: 'true'
    test-directories: 'test/ test/integration/ test/e2e/'
    flutter-command: 'fvm flutter'
```

## Inputs

| Input Name | Description | Default | Required |
|------------|-------------|---------|----------|
| `enable-code-coverage` | Generate code coverage reports | `true` | No |
| `test-directories` | Space-separated list of test directories | `test/ test/presentation/ui/shared/services/ test/drift/app_database/` | No |
| `flutter-command` | Flutter command to use | `fvm flutter` | No |
| `run-build-runner` | Run build_runner before tests | `true` | No |
| `upload-coverage` | Upload coverage to Codecov | `false` | No |
| `cache-key-suffix` | Cache key suffix for optimization | `linux-tests` | No |

## Outputs

| Output Name | Description |
|-------------|-------------|
| `test-result` | Test execution result (success/failure) |
| `test-count` | Total number of tests run |
| `coverage-percentage` | Code coverage percentage |

## What the Action Does

1. **Setup Flutter Environment** - Uses the setup-fvm action
2. **Install Dependencies** - Uses the install-flutter-deps action
3. **Run build_runner** - Generates code if enabled
4. **Create Test Results Directory** - Prepares directories for test outputs
5. **Run Unit and Widget Tests** - Core application tests with optional coverage
6. **Run Additional Test Suites** - Custom test directories specified in inputs
7. **Process Coverage Reports** - Generates and processes coverage information
8. **Run Localization Tests** - Tests for translation completeness
9. **Run Migration Tests** - Database migration validation tests
10. **Upload Coverage to Codecov** - If enabled and configured
11. **Generate Test Summary** - Creates a summary of test results
12. **Upload Test Results** - Saves test logs and results as artifacts
13. **Upload Coverage Reports** - Saves coverage reports as artifacts
14. **Display Test Summary** - Shows results in GitHub Actions summary

## Example Workflows

### Complete Test Workflow

```yaml
name: Comprehensive Tests

on:
  push:
    branches: [main, develop]
  pull_request:

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v4
        with:
          submodules: false

      - name: Initialize Submodules
        uses: ./.github/actions/setup-repository

      - name: Run Tests
        uses: ./.github/actions/run-tests
        with:
          enable-code-coverage: 'true'
          upload-coverage: 'true'
          test-directories: 'test/ test/integration/ test/e2e/'
```

### Simple Test Workflow (No Coverage)

```yaml
name: Quick Tests

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v4
        with:
          submodules: false

      - name: Initialize Submodules
        uses: ./.github/actions/setup-repository

      - name: Run Tests
        uses: ./.github/actions/run-tests
        with:
          enable-code-coverage: 'false'
          run-build-runner: 'false'
```

## Dependencies

This action requires:

- Linux runner (ubuntu-latest recommended)
- lcov package (for coverage processing)
- Access to the following actions:
  - `./.github/actions/setup-fvm`
  - `./.github/actions/install-flutter-deps`
  - `./.github/actions/setup-repository`

## Troubleshooting

### Tests Fail with "No pubspec.yaml found"

Ensure the `setup-repository` action is run before this action to properly initialize the acore submodule.

### Coverage Reports Not Generated

Make sure `lcov` is installed on the runner:
```bash
sudo apt-get install lcov
```

### Test Directories Not Found

The specified test directories must exist relative to the `src/` directory. Use absolute paths from the project root if needed.

## Artifacts

The action generates the following artifacts:

- `test-results-{suffix}` - All test logs and outputs
- `coverage-reports-{suffix}` - Coverage reports in LCOV and HTML format (if enabled)

Where `{suffix}` is the value of `cache-key-suffix` input.
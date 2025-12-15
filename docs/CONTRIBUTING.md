# Contributing to WHPH

Thank you for your interest in contributing to WHPH! This guide will help you get started and ensure your contributions are consistent and high-quality.

## 1. Setting Up the Development Environment

- **Prerequisites:**
  - [FVM (Flutter Version Management)](https://fvm.app/docs/getting_started/installation)
  - Compatible device or emulator for Windows, Linux, or Android
- **Install FVM:**
  Follow the installation instructions on the [official FVM website](https://fvm.app/docs/getting_started/installation) for your operating system.
- **Clone the repository (with submodules):**

  ```bash
  git clone --recurse-submodules https://github.com/ahmet-cetinkaya/whph.git
  ```

  If you already cloned without `--recurse-submodules`, run:

  ```bash
  git submodule update --init --recursive
  ```

- **Navigate into the project directory:**

  ```bash
  cd whph
  ```

- **Install the project's Flutter version using FVM:**

  ```bash
  fvm install
  fvm use
  ```

  This will automatically install and use the Flutter version specified in the `.fvmrc` file.
- **Install dependencies:**

  ```bash
  fvm flutter pub get
  ```

- **Start the application:**

  ```bash
  fvm flutter run
  ```

> **Note:** This project uses FVM to ensure all contributors use the same Flutter version. Always use `fvm flutter` instead of `flutter` when running commands.

## 2. Code Style and Formatting Requirements

- Write idiomatic Flutter and Dart code.
- Use null safety and modern Flutter syntax.
- Keep UI code declarative and component-based using `Widget` classes or functions.
- Prefer `const` constructors where possible.
- Use `StatelessWidget` unless state is explicitly needed.
- Use `SizedBox` for spacing when no decoration is needed.
- Use `Padding`, `Margin`, `Align`, and `Expanded` appropriately in layout trees.
- Group widget trees with descriptive comments for better organization.
- Avoid suggesting `setState` for complex applications; use appropriate state management.
- Use `Theme.of(context)` for theme values and avoid hardcoding styles or colors.
- Use `.withValues()` for colors to maintain consistency with the theme.
- Use camelCase for variables and methods, PascalCase for class names and widgets.
- Prefer async/await over `then()` for readability.
- Use `FutureBuilder` and `StreamBuilder` for async data in the UI.
- Use `ListView.builder` for large lists.
- Use `final` for variables that are not reassigned, `const` for compile-time constants.
- Follow SOLID principles and DRY (Don't Repeat Yourself).
- Add explanatory comments only for non-obvious logic.
- Implement robust error handling and input validation.
- Avoid magic strings/numbers; use constants or enums.
- Follow security best practices and defensive programming techniques.
- Avoid `MediaQuery.of(context)`; use specific methods like `MediaQuery.sizeOf(context)`.

## 3. How to Submit Pull Requests

1. **Fork the repository**
2. **Create a new branch**

   ```bash
   git checkout -b feat/feature-branch
   ```

3. **Make your changes**
4. **Commit your changes**

   ```bash
   git commit -m 'feat: add new feature'
   ```

5. **Push to your branch**

   ```bash
   git push origin feat/feature-branch
   ```

6. **Open a Pull Request**
   - Provide a clear description of your changes and reference any related issues.
   - Ensure your branch is up to date with `main` before submitting.
   - Follow the pull request template if available.

## 4. Issue Reporting Guidelines

- Search for existing issues before opening a new one.
- Provide a clear and descriptive title.
- Include steps to reproduce, expected behavior, and actual behavior.
- Attach relevant logs, screenshots, or error messages.
- Specify your environment (OS, device, Flutter/Dart version).

## 5. Testing Requirements

- Write tests for new features and bug fixes.
- Ensure all existing and new tests pass before submitting a pull request.
- Use the test suite in the `test/` directory:

  ```bash
  fvm flutter test
  ```

- Prefer widget, unit, and integration tests as appropriate.
- Test on all supported platforms (Android, Windows, Linux) if possible.

## 6. Project-Specific Contribution Workflows

- Adhere to the code style and guidelines outlined above.
- Use conventional commit messages (e.g., `feat:`, `fix:`, `docs:`).
- Update documentation as needed for new features or changes.
- Run `fvm flutter analyze` and address any warnings or errors.
- Always use `fvm flutter` instead of `flutter` for consistency with the project's Flutter version management.
- You can also use the RPS commands defined in `pubspec.yaml` for common tasks:

  ```bash
  # Install RPS globally (if not already installed)
  dart pub global activate rps

  # Run common commands
  rps test          # Run tests
  rps clean         # Clean build artifacts
  rps format        # Format code
  rps gen           # Generate code
  rps run           # Run the app
  rps run:demo      # Run in demo mode
  ```

- If your change affects the build or deployment, update relevant scripts or documentation.
- For native code integration, use platform channels and defined constants.
- Respect licensing and third-party dependencies.

---

For any questions, please open an issue or contact the maintainers. Happy contributing!

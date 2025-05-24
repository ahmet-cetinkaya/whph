## General Guidelines
- Write idiomatic Flutter and Dart code.
- Prefer null safety and modern Flutter syntax.
- Keep UI code declarative and component-based using `Widget` classes or functions.

## Widget Usage
- Prefer `const` constructors where possible.
- Use `StatelessWidget` unless state is explicitly needed.
- Prefer `SizedBox` over `Container` for spacing when no decoration is needed.
- Use `Padding`, `Margin`, `Align`, and `Expanded` appropriately in layout trees.
- Group widget trees with descriptive comments for better organization:
  * Use section comments for UI sections:
    ```dart
    // Header Section
    AppBar(...),

    // Main Content Section
    Expanded(
      child: ListView(...),
    ),
    ```

## State Management
- Avoid suggesting `setState` for complex applications; use appropriate state management.

## Theming
- Use `Theme.of(context)` to access theme values.
- Avoid hardcoding styles or colors.

## Naming Conventions

* Use camelCase for variables and methods.
* Use PascalCase for class names and widgets.

## Misc
* Prefer async/await over `then()` for better readability.
* Use `FutureBuilder` and `StreamBuilder` when dealing with async data in the UI.
* `withOpacity` is deprecated and shouldn't be used. Use `.withValues()` to avoid precision loss.
* Use `ListView.builder` for large lists instead of `ListView` with a static list.
* Use `const` constructors for widgets that do not depend on runtime values.
* Use `final` for variables that are not reassigned.
* Use `const` for compile-time constants.
* Use `async` and `await` for asynchronous operations.
* Use method for event handlers instead of inline functions.
## General Guidelines
- Write idiomatic Flutter and Dart code.
- Prefer null safety and modern Flutter syntax.
- Keep UI code declarative and component-based using `Widget` classes or functions.

## Widget Usage
- Prefer `const` constructors where possible.
- Use `StatelessWidget` unless state is explicitly needed.
- Prefer `SizedBox` over `Container` for spacing when no decoration is needed.
- Use `Padding`, `Margin`, `Align`, and `Expanded` appropriately in layout trees.

## Color and Style

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

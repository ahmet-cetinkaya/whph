# Phase 6: UI Components (Optional)

## Overview

This phase covers creating UI for users to manage your entity (settings pages,
lists, forms). This is optional for entities managed only through code.

## When UI Is Needed

**Yes** if:

- Users create/edit/delete the entity
- Entity has user-facing names/colors/settings
- Entity appears in grouping/filtering UI

**No** if:

- Entity is system-only (internal state, logs, etc.)
- Entity is managed through parent entity UI
- Entity is created automatically

## Settings Component Structure

**Location**:
`lib/presentation/ui/features/<feature>/components/<feature>_<entity>s_setting.dart`

```dart
import 'package:flutter/material.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/ui/shared/components/responsive_scaffold_layout.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_translation_service.dart';

class YourEntitiesSetting extends StatefulWidget {
  final VoidCallback? onLoaded;

  const YourEntitiesSetting({
    super.key,
    this.onLoaded,
  });

  @override
  State<YourEntitiesSetting> createState() => _YourEntitiesSettingState();
}

class _YourEntitiesSettingState extends State<YourEntitiesSetting> {
  final _mediator = container.resolve<Mediator>();
  final _translationService = container.resolve<ITranslationService>();
  List<YourEntityListItem> _entities = [];
  final double _orderStep = 1000.0;  // For persistent ordering
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadEntities();
  }

  Future<void> _loadEntities() async {
    setState(() => _isLoading = true);
    try {
      final result = await _mediator.send(GetListYourEntitiesQuery());
      setState(() {
        _entities = result;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    }
  }

  Future<void> _saveEntity(YourEntityListItem item) async {
    try {
      await _mediator.send(SaveYourEntityCommand(
        id: item.id,
        field1: item.field1,
        nullableField: item.nullableField,
        order: item.order,
        isBuiltIn: item.isBuiltIn,
      ));
      await _loadEntities();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    }
  }

  Future<void> _deleteEntity(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_translationService.translate(YourEntityTranslationKeys.entityDeleteConfirmTitle)),
        content: Text(_translationService.translate(YourEntityTranslationKeys.entityDeleteConfirmMessage)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(_translationService.translate(SharedTranslationKeys.cancel)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(_translationService.translate(SharedTranslationKeys.delete)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _mediator.send(DeleteYourEntityCommand(id: id));
        await _loadEntities();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.toString())),
          );
        }
      }
    }
  }

  void _onReorder(int oldIndex, int newIndex) {
    if (oldIndex < newIndex) newIndex -= 1;
    final reordered = List<YourEntityListItem>.from(_entities);
    final item = reordered.removeAt(oldIndex);
    reordered.insert(newIndex, item);

    // Recalculate orders with _orderStep
    for (int i = 0; i < reordered.length; i++) {
      final updated = reordered[i];
      reordered[i] = YourEntityListItem(
        id: updated.id,
        field1: updated.field1,
        nullableField: updated.nullableField,
        order: (i + 1) * _orderStep,
        isBuiltIn: updated.isBuiltIn,
      );
      _saveEntity(reordered[i]);
    }

    setState(() => _entities = reordered);
  }

  void _addEntity() {
    // Navigate to add/edit screen or show dialog
    // Example: showDialog with form
  }

  @override
  Widget build(BuildContext context) {
    return ResponsiveScaffoldLayout(
      title: _translationService.translate(YourEntityTranslationKeys.entitiesSettingsTitle),
      showBackButton: true,
      hideSidebar: true,
      showLogo: false,
      builder: (context) => _isLoading
        ? Center(child: CircularProgressIndicator())
        : Card(
            child: Column(
              children: [
                ReorderableListView(
                  shrinkWrap: true,
                  onReorder: _onReorder,
                  children: _entities.map((entity) => ListTile(
                    key: ValueKey(entity.id),
                    leading: entity.nullableField != null
                      ? CircleAvatar(backgroundColor: Color(int.parse(entity.nullableField!)))
                      : Icon(Icons.circle),
                    title: Text(entity.field1),
                    trailing: IconButton(
                      icon: Icon(Icons.delete),
                      onPressed: entity.isBuiltIn ? null : () => _deleteEntity(entity.id),
                    ),
                  )).toList(),
                ),
                Padding(
                  padding: EdgeInsets.all(16),
                  child: ElevatedButton(
                    onPressed: _addEntity,
                    child: Text(_translationService.translate(YourEntityTranslationKeys.entityAddButton)),
                  ),
                ),
              ],
            ),
          ),
    );
  }
}
```

### Settings Component Patterns

| Pattern               | Purpose                                |
| --------------------- | -------------------------------------- |
| `Mediator`            | Send commands/queries via CQRS         |
| `ITranslationService` | Localize all user-facing strings       |
| `_orderStep = 1000.0` | Persistent reordering (allows inserts) |
| Built-in guards       | Disable delete for system entities     |
| Error handling        | Show errors in SnackBars               |

## Ordering Pattern

The `_orderStep` pattern allows inserting items between existing ones without
reordering all:

```dart
void _onReorder(int oldIndex, int newIndex) {
  // Recalculate: order = (i + 1) * _orderStep
  // Result: 1000, 2000, 3000, 4000, ...
}
```

To insert between 2000 and 3000, use 2500.

## Color Picker Integration

If your entity has a color field, reuse `ColorField`:

**Location**:
`lib/presentation/ui/shared/components/color_picker/color_field.dart`

```dart
import 'package:whph/presentation/ui/shared/components/color_picker/color_field.dart';

// In your widget:
ColorField(
  initialColor: entity.color,
  onColorChanged: (color) {
    // Save updated entity
  },
)
```

## Display Helpers for Built-ins

If built-in entities use localized defaults when empty:

**Location**:
`lib/presentation/ui/features/<feature>/utils/<entity>_display.dart`

```dart
class YourEntityDisplay {
  static String resolveName({
    required String? name,
    required bool isBuiltIn,
    required ITranslationService translationService,
  }) {
    if (name.isNotEmpty) return name;
    if (!isBuiltIn) return name;

    // Empty built-in: use localized default
    return translationService.translate(YourEntityTranslationKeys.entityBuiltinName);
  }
}
```

## Translation Keys

Add to both application and presentation translation files:

**Location**:
`lib/core/application/features/<feature>/constants/<feature>_translation_keys.dart`

**Location**:
`lib/presentation/ui/features/<feature>/constants/<feature>_translation_keys.dart`

```dart
class YourEntityTranslationKeys {
  // Errors
  static const String entityNotFound = '<feature>.errors.entity_not_found';

  // Settings page
  static const String entitiesSettingsTitle = '<feature>.entities.settings.title';
  static const String entitiesSettingsDescription = '<feature>.entities.settings.description';

  // Add/Edit
  static const String entityAddButton = '<feature>.entities.add_button';
  static const String entityNameLabel = '<feature>.entities.name_label';
  static const String entityNameHint = '<feature>.entities.name_hint';
  static const String entityColorLabel = '<feature>.entities.color_label';

  // Delete
  static const String entityDeleteConfirmTitle = '<feature>.entities.delete_confirm.title';
  static const String entityDeleteConfirmMessage = '<feature>.entities.delete_confirm.message';

  // Built-in defaults
  static const String entityBuiltinName = '<feature>.entities.builtin.name';
  static const String entityNewDefaultName = '<feature>.entities.new_default_name';
}
```

### Reuse Shared Keys

When possible, reuse shared translation keys:

```dart
import 'package:whph/core/application/shared/constants/shared_translation_keys.dart';

// Use:
SharedTranslationKeys.save
SharedTranslationKeys.cancel
SharedTranslationKeys.delete
```

## Locale YAML Updates

Add translations to all locale files:

**Location**: `lib/presentation/ui/features/<feature>/assets/locales/*.yaml`

```yaml
<feature>:
  errors:
    entity_not_found: "Entity not found"
  entities:
    settings:
      title: "Your Entities"
      description: "Manage custom entities"
    add_button: "Add Entity"
    name_label: "Name"
    name_hint: "Enter entity name"
    color_label: "Color"
    delete_confirm:
      title: "Delete Entity?"
      message: "This action cannot be undone"
    builtin:
      name: "Default Entity"
    new_default_name: "New Entity"
```

### Locale Files to Update

Update all 22 locale files:

- `en.yaml` (English)
- `tr.yaml` (Turkish)
- `de.yaml` (German)
- `fr.yaml` (French)
- `es.yaml` (Spanish)
- `it.yaml` (Italian)
- `pt.yaml` (Portuguese)
- `ru.yaml` (Russian)
- `ja.yaml` (Japanese)
- `ko.yaml` (Korean)
- `zh.yaml` (Chinese)
- And 10 more...

Run `rps test:locale` to verify completeness.

## Integrate into Settings Page

**Location**:
`lib/presentation/ui/features/settings/components/<feature>_settings.dart`

```dart
class YourFeatureSettings extends StatefulWidget {
  @override
  Widget build(BuildContext context) {
    return ResponsiveScaffoldLayout(
      title: _translationService.translate(YourFeatureTranslationKeys.settingsTitle),
      builder: (context) => SingleChildScrollView(
        child: Column(
          children: [
            // ... other settings
            SizedBox(height: AppTheme.sizeMedium),
            YourEntitiesSetting(),
          ],
        ),
      ),
    );
  }
}
```

## Next Steps

After UI components:

→ [Code Generation & Verification](./07_CODE_GENERATION_AND_VERIFICATION.md)

---

**See also**: [Common Patterns](./08_COMMON_PATTERNS.md) for UI-specific
conventions.

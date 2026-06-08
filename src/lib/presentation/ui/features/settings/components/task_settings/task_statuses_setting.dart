import 'dart:async';

import 'package:acore/acore.dart';
import 'package:flutter/material.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/core/application/features/tasks/commands/delete_task_status_command.dart';
import 'package:whph/core/application/features/tasks/commands/save_task_status_command.dart';
import 'package:whph/core/application/features/tasks/queries/get_list_task_statuses_query.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/ui/features/tasks/constants/task_translation_keys.dart';
import 'package:whph/presentation/ui/features/tasks/utils/task_status_display.dart';
import 'package:whph/presentation/ui/shared/components/color_picker/color_field.dart';
import 'package:whph/presentation/ui/shared/components/styled_icon.dart';
import 'package:whph/presentation/ui/shared/constants/app_theme.dart';
import 'package:whph/presentation/ui/shared/constants/shared_translation_keys.dart';
import 'package:whph/core/domain/shared/utils/logger.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/presentation/ui/shared/utils/async_error_handler.dart';
import 'package:whph/presentation/ui/shared/utils/overlay_notification_helper.dart';

/// Settings card for managing task statuses: rename, recolor, reorder, add and
/// delete. Built-in statuses (todo/done) cannot be deleted and display a
/// localized default name until renamed.
class TaskStatusesSetting extends StatefulWidget {
  const TaskStatusesSetting({super.key});

  @override
  State<TaskStatusesSetting> createState() => _TaskStatusesSettingState();
}

class _TaskStatusesSettingState extends State<TaskStatusesSetting> {
  final _mediator = container.resolve<Mediator>();
  final _translationService = container.resolve<ITranslationService>();

  List<TaskStatusListItem> _statuses = const [];
  final Map<String, TextEditingController> _nameControllers = {};
  final Map<String, String?> _lastSyncedNames = {};
  final Map<String, Timer> _debounces = {};

  static const double _orderStep = 1000.0;
  static const Duration _debounceDelay = Duration(milliseconds: 500);

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final debounce in _debounces.values) {
      debounce.cancel();
    }
    for (final controller in _nameControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    await AsyncErrorHandler.execute<GetListTaskStatusesQueryResponse>(
      context: context,
      errorMessage: _translationService.translate(SharedTranslationKeys.unexpectedError),
      operation: () => _mediator.send<GetListTaskStatusesQuery, GetListTaskStatusesQueryResponse>(
        const GetListTaskStatusesQuery(pageIndex: 0, pageSize: 100),
      ),
      onSuccess: (result) {
        setState(() {
          _statuses = result.items;
          _syncControllers();
        });
      },
    );
  }

  /// Keeps the per-status name controllers in sync with the loaded statuses.
  /// Built-in statuses display their localized default when unnamed.
  /// Uses smart dirty checking to avoid overwriting user input.
  void _syncControllers() {
    final activeIds = _statuses.map((s) => s.id).toSet();
    _nameControllers.removeWhere((id, controller) {
      if (!activeIds.contains(id)) {
        controller.dispose();
        _lastSyncedNames.remove(id);
        return true;
      }
      return false;
    });

    for (final status in _statuses) {
      final displayName = TaskStatusDisplay.resolveName(
        _translationService,
        id: status.id,
        name: status.name,
        isDoneStatus: status.isDoneStatus,
      );

      // Track last synced name for dirty checking
      _lastSyncedNames.putIfAbsent(status.id, () => status.name);
      final existing = _nameControllers[status.id];
      if (existing == null) {
        _nameControllers[status.id] = TextEditingController(text: displayName);
        _lastSyncedNames[status.id] = status.name;
      } else {
        // Only update controller if:
        // 1. Controller text matches last synced value (not dirty) AND
        // 2. New value is different from controller
        final lastSynced = _lastSyncedNames[status.id];
        final isDirty = existing.text != (lastSynced ?? '');
        if (!isDirty && existing.text != displayName) {
          existing.text = displayName;
          _lastSyncedNames[status.id] = status.name;
        }
      }
    }
  }

  Color? _colorFromHex(String? hex) => TaskStatusDisplay.parseColor(hex);

  /// Saves a status change with optimistic UI update.
  Future<void> _save(TaskStatusListItem status, {String? name, String? color}) async {
    final newName = name ?? status.name;
    final newColor = color ?? status.color;

    // Update local state immediately (optimistic UI)
    setState(() {
      final index = _statuses.indexWhere((s) => s.id == status.id);
      if (index != -1) {
        _statuses[index] = TaskStatusListItem(
          id: status.id,
          name: newName,
          color: newColor,
          order: status.order,
          isBuiltIn: status.isBuiltIn,
          isDoneStatus: status.isDoneStatus,
        );
      }
    });

    // Update last synced to match optimistic update
    if (name != null) {
      _lastSyncedNames[status.id] = name;
    }

    // Background save - show error if fails but don't reload
    try {
      await _mediator.send<SaveTaskStatusCommand, SaveTaskStatusCommandResponse>(
        SaveTaskStatusCommand(
          id: status.id,
          name: newName,
          color: newColor,
          order: status.order,
        ),
      );
    } catch (e) {
      Logger.error('Failed to save task status: $e');
      if (mounted) {
        _load();
        OverlayNotificationHelper.showError(
          context: context,
          message: _translationService.translate(SharedTranslationKeys.unexpectedError),
        );
      }
    }
  }

  /// Debounced save for name changes (fires on every keystroke, debounced)
  void _onNameChanged(TaskStatusListItem status, String value) {
    final trimmed = value.trim();
    final nameToSave = trimmed.isEmpty ? '' : trimmed;

    // Update local state immediately
    setState(() {
      final index = _statuses.indexWhere((s) => s.id == status.id);
      if (index != -1) {
        _statuses[index] = TaskStatusListItem(
          id: status.id,
          name: nameToSave,
          color: status.color,
          order: status.order,
          isBuiltIn: status.isBuiltIn,
          isDoneStatus: status.isDoneStatus,
        );
      }
    });

    // Update last synced to prevent _syncControllers from overwriting during typing
    _lastSyncedNames[status.id] = nameToSave;

    // Cancel existing debounce for this status
    _debounces[status.id]?.cancel();

    // Schedule debounced save
    _debounces[status.id] = Timer(_debounceDelay, () {
      _save(status, name: nameToSave);
      _debounces.remove(status.id);
    });
  }

  Future<void> _add() async {
    final newName = _translationService.translate(TaskTranslationKeys.statusNewDefaultName);
    final maxOrder = _statuses.isEmpty ? 0.0 : _statuses.map((s) => s.order).reduce((a, b) => a > b ? a : b);

    await AsyncErrorHandler.execute<SaveTaskStatusCommandResponse>(
      context: context,
      errorMessage: _translationService.translate(SharedTranslationKeys.savingError),
      operation: () => _mediator.send<SaveTaskStatusCommand, SaveTaskStatusCommandResponse>(
        SaveTaskStatusCommand(name: newName, order: maxOrder + _orderStep),
      ),
      onSuccess: (_) => _load(),
    );
  }

  Future<void> _delete(TaskStatusListItem status) async {
    await AsyncErrorHandler.execute<DeleteTaskStatusCommandResponse>(
      context: context,
      errorMessage: _translationService.translate(SharedTranslationKeys.deletingError),
      operation: () => _mediator.send<DeleteTaskStatusCommand, DeleteTaskStatusCommandResponse>(
        DeleteTaskStatusCommand(id: status.id),
      ),
      onSuccess: (_) => _load(),
    );
  }

  Future<void> _reorder(int oldIndex, int newIndex) async {
    if (newIndex > oldIndex) newIndex -= 1;
    final reordered = List<TaskStatusListItem>.from(_statuses);
    final moved = reordered.removeAt(oldIndex);
    reordered.insert(newIndex, moved);

    setState(() => _statuses = reordered);

    try {
      for (var i = 0; i < reordered.length; i++) {
        final status = reordered[i];
        final newOrder = (i + 1) * _orderStep;
        if (status.order != newOrder) {
          await _mediator.send<SaveTaskStatusCommand, SaveTaskStatusCommandResponse>(
            SaveTaskStatusCommand(id: status.id, name: status.name, color: status.color, order: newOrder),
          );
        }
      }
    } catch (e) {
      Logger.error('Failed to reorder task statuses: $e');
      if (mounted) {
        OverlayNotificationHelper.showError(
          context: context,
          message: _translationService.translate(SharedTranslationKeys.unexpectedError),
        );
      }
    }

    if (mounted) {
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: AppTheme.surface2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.sizeLarge),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const StyledIcon(
                  Icons.view_column_outlined,
                  isActive: true,
                ),
                const SizedBox(width: AppTheme.sizeMedium),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              _translationService.translate(TaskTranslationKeys.statusSettingsTitle),
                              style: AppTheme.labelLarge,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.add),
                            tooltip: _translationService.translate(TaskTranslationKeys.statusAddButton),
                            onPressed: _add,
                          ),
                        ],
                      ),
                      const SizedBox(height: AppTheme.sizeSmall),
                      Text(
                        _translationService.translate(TaskTranslationKeys.statusSettingsDescription),
                        style: AppTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.sizeMedium),
            ReorderableListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              buildDefaultDragHandles: false,
              itemCount: _statuses.length,
              onReorder: _reorder,
              itemBuilder: (context, index) {
                final status = _statuses[index];
                return _buildStatusRow(status, index, key: ValueKey(status.id));
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusRow(TaskStatusListItem status, int index, {required Key key}) {
    final controller = _nameControllers[status.id]!;

    return Padding(
      key: key,
      padding: const EdgeInsets.symmetric(vertical: AppTheme.size2XSmall),
      child: Row(
        children: [
          ReorderableDragStartListener(
            index: index,
            child: Icon(Icons.drag_handle, color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
          const SizedBox(width: AppTheme.sizeSmall),
          ColorField(
            initialColor: _colorFromHex(status.color),
            onColorChanged: (color) => _save(status, color: color.toHexString()),
          ),
          const SizedBox(width: AppTheme.sizeSmall),
          Expanded(
            child: TextField(
              controller: controller,
              decoration: InputDecoration(
                isDense: true,
                hintText: _translationService.translate(TaskTranslationKeys.statusNameHint),
              ),
              onChanged: (value) => _onNameChanged(status, value),
              onSubmitted: (value) {
                // Cancel any pending debounce and save immediately
                _debounces[status.id]?.cancel();
                _debounces.remove(status.id);
                final trimmed = value.trim();
                if (trimmed.isEmpty) {
                  // Empty names are reserved for un-renamed built-ins; restore display.
                  _syncControllers();
                  setState(() {});
                  return;
                }
                _save(status, name: trimmed);
              },
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: _translationService.translate(SharedTranslationKeys.deleteButton),
            onPressed: status.isBuiltIn ? null : () => _confirmDelete(status),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(TaskStatusListItem status) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_translationService.translate(TaskTranslationKeys.statusDeleteConfirmTitle)),
        content: Text(_translationService.translate(TaskTranslationKeys.statusDeleteConfirmMessage)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(_translationService.translate(SharedTranslationKeys.cancelButton)),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(_translationService.translate(SharedTranslationKeys.deleteButton)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _delete(status);
    }
  }
}

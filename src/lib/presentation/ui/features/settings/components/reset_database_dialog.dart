import 'package:flutter/material.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/core/application/features/settings/commands/reset_database_command.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/ui/features/settings/constants/settings_translation_keys.dart';
import 'package:whph/presentation/ui/shared/constants/app_theme.dart';
import 'package:whph/presentation/ui/shared/constants/shared_translation_keys.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_translation_service.dart';
import 'package:flutter_phoenix/flutter_phoenix.dart';

import 'package:whph/core/shared/utils/logger.dart';
import 'package:whph/presentation/ui/shared/utils/overlay_notification_helper.dart';

class ResetDatabaseDialog extends StatefulWidget {
  const ResetDatabaseDialog({super.key});

  @override
  State<ResetDatabaseDialog> createState() => _ResetDatabaseDialogState();
}

class _ResetDatabaseDialogState extends State<ResetDatabaseDialog> {
  final _translationService = container.resolve<ITranslationService>();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          _translationService.translate(SettingsTranslationKeys.resetDatabaseTitle),
        ),
        elevation: 0,
        actions: const [
          SizedBox(width: AppTheme.sizeSmall),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.sizeMedium),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: AppTheme.sizeLarge),
              Icon(
                Icons.warning_amber_rounded,
                color: theme.colorScheme.error,
                size: 64,
              ),
              const SizedBox(height: AppTheme.sizeMedium),
              Text(
                _translationService.translate(SettingsTranslationKeys.resetDatabaseTitle),
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppTheme.sizeSmall),
              Text(
                _translationService.translate(SettingsTranslationKeys.resetDatabaseConfirmationMessage),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppTheme.sizeLarge),
              const SizedBox(height: AppTheme.sizeLarge),
              _SwipeToConfirm(
                onConfirmed: () => _handleResetDatabase(context),
                label: _translationService.translate(SharedTranslationKeys.deleteButton),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleResetDatabase(BuildContext context) async {
    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      // Perform reset via Mediator
      final mediator = container.resolve<Mediator>();
      await mediator.send(ResetDatabaseCommand());

      if (context.mounted) {
        // Close loading dialog
        Navigator.pop(context);

        // Show success message
        OverlayNotificationHelper.showSuccess(
          context: context,
          message: _translationService.translate(SettingsTranslationKeys.resetDatabaseSuccess),
        );

        // Wait a moment to show the success message before restarting
        await Future.delayed(const Duration(seconds: 2));

        // Restart the application to ensure a clean state after database reset
        if (context.mounted) {
          Logger.info('🔄 Restarting application after successful database reset');
          Phoenix.rebirth(context);
        }
      }
    } catch (e, stackTrace) {
      if (context.mounted) {
        // Close loading dialog
        Navigator.pop(context);

        Logger.error('Failed to reset database: $e\n$stackTrace');

        OverlayNotificationHelper.showError(
          context: context,
          message: '${_translationService.translate(SharedTranslationKeys.unexpectedError)}: $e',
        );
      }
    }
  }
}

class _SwipeToConfirm extends StatefulWidget {
  final VoidCallback onConfirmed;
  final String label;

  const _SwipeToConfirm({
    required this.onConfirmed,
    required this.label,
  });

  @override
  State<_SwipeToConfirm> createState() => _SwipeToConfirmState();
}

class _SwipeToConfirmState extends State<_SwipeToConfirm> {
  double _dragValue = 0.0;
  final double _height = 56.0;
  final double _padding = 4.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final errorColor = theme.colorScheme.error;

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth;
        final sliderWidth = _height - (_padding * 2);
        final maxDrag = maxWidth - _height;

        return Container(
          height: _height,
          decoration: BoxDecoration(
            color: errorColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(_height / 2),
            border: Border.all(color: errorColor.withValues(alpha: 0.3)),
          ),
          child: Stack(
            children: [
              Center(
                child: Text(
                  widget.label.toUpperCase(),
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: errorColor,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              Positioned(
                left: _padding + (_dragValue * maxDrag),
                top: _padding,
                bottom: _padding,
                child: GestureDetector(
                  onHorizontalDragUpdate: (details) {
                    setState(() {
                      _dragValue = (_dragValue + details.primaryDelta! / maxDrag).clamp(0.0, 1.0);
                    });
                  },
                  onHorizontalDragEnd: (details) {
                    if (_dragValue > 0.9) {
                      setState(() {
                        _dragValue = 1.0;
                      });
                      widget.onConfirmed();
                      // Reset after a delay if needed, or keep it at end
                      Future.delayed(const Duration(seconds: 1), () {
                        if (mounted) {
                          setState(() {
                            _dragValue = 0.0;
                          });
                        }
                      });
                    } else {
                      setState(() {
                        _dragValue = 0.0;
                      });
                    }
                  },
                  child: Container(
                    width: sliderWidth,
                    height: sliderWidth,
                    decoration: BoxDecoration(
                      color: errorColor,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: errorColor.withValues(alpha: 0.4),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.chevron_right,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

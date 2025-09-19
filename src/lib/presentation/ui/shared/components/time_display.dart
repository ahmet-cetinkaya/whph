import 'package:flutter/material.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/ui/shared/constants/app_theme.dart';
import 'package:whph/presentation/ui/shared/constants/shared_translation_keys.dart';
import 'package:whph/presentation/ui/shared/constants/shared_ui_constants.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_translation_service.dart';

class TimeDisplay extends StatefulWidget {
  final int totalSeconds;
  final int? estimatedMinutes;
  final bool showEstimatedFallback;
  final VoidCallback? onTap;

  const TimeDisplay({
    super.key,
    required this.totalSeconds,
    this.estimatedMinutes,
    this.showEstimatedFallback = false,
    this.onTap,
  });

  @override
  State<TimeDisplay> createState() => _TimeDisplayState();
}

class _TimeDisplayState extends State<TimeDisplay> {
  late final ITranslationService _translationService = container.resolve<ITranslationService>();

  String _getDisplayText() {
    final actualMinutes = widget.totalSeconds ~/ 60;
    if (widget.showEstimatedFallback &&
        actualMinutes == 0 &&
        widget.estimatedMinutes != null &&
        widget.estimatedMinutes! > 0) {
      final estimatedText = SharedUiConstants.formatDurationHuman(widget.estimatedMinutes!, _translationService);
      return '~$estimatedText (${_translationService.translate(SharedTranslationKeys.timeDisplayEstimated)})';
    }
    return SharedUiConstants.formatDurationHuman(actualMinutes, _translationService);
  }

  String _getTooltipText() {
    final actualMinutes = widget.totalSeconds ~/ 60;
    if (widget.showEstimatedFallback &&
        actualMinutes == 0 &&
        widget.estimatedMinutes != null &&
        widget.estimatedMinutes! > 0) {
      return _translationService.translate(SharedTranslationKeys.timeDisplayEstimatedTimeTooltip);
    } else if (actualMinutes > 0) {
      return 'Actual time tracked';
    } else {
      return _translationService.translate(SharedTranslationKeys.timeDisplayNoTimeLoggedTooltip);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textColor =
        (widget.totalSeconds > 0) ? theme.colorScheme.onSurface : theme.colorScheme.onSurface.withValues(alpha: 0.7);

    final textWidget = Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.sizeSmall),
      child: Text(
        _getDisplayText(),
        style: TextStyle(
          fontWeight: (widget.totalSeconds > 0) ? FontWeight.bold : FontWeight.normal,
          color: textColor,
        ),
      ),
    );

    if (widget.onTap == null) {
      return Tooltip(
        message: _getTooltipText(),
        child: textWidget,
      );
    }

    return Tooltip(
      message: _getTooltipText(),
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          height: 36,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Expanded(child: textWidget),
            ],
          ),
        ),
      ),
    );
  }
}

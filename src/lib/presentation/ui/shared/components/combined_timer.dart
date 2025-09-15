import 'package:flutter/material.dart';
import 'package:whph/presentation/ui/shared/components/normal_timer.dart';
import 'package:whph/presentation/ui/features/tasks/components/pomodoro_timer.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/main.dart';

enum TimerMode { normal, pomodoro }

class CombinedTimer extends StatefulWidget {
  final TimerMode initialMode;
  final Function(Duration) onTimeUpdate;
  final VoidCallback? onTimerStart;
  final VoidCallback? onTimerStop;
  final VoidCallback? onModeChange;

  const CombinedTimer({
    super.key,
    this.initialMode = TimerMode.normal,
    required this.onTimeUpdate,
    this.onTimerStart,
    this.onTimerStop,
    this.onModeChange,
  });

  @override
  State<CombinedTimer> createState() => _CombinedTimerState();
}

class _CombinedTimerState extends State<CombinedTimer> {
  final _translationService = container.resolve<ITranslationService>();
  late TimerMode _currentMode;

  @override
  void initState() {
    super.initState();
    _currentMode = widget.initialMode;
  }

  void _switchMode(TimerMode mode) {
    if (_currentMode == mode) return;

    setState(() {
      _currentMode = mode;
    });

    widget.onModeChange?.call();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Mode Selector (Segmented Control)
        Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainer,
            borderRadius: BorderRadius.circular(8.0),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildModeButton(
                mode: TimerMode.normal,
                label: _translationService.translate('Normal Timer'),
                icon: Icons.timer,
              ),
              _buildModeButton(
                mode: TimerMode.pomodoro,
                label: _translationService.translate('Pomodoro'),
                icon: Icons.timer_outlined,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16.0),

        // Timer Widget
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: _currentMode == TimerMode.normal
              ? NormalTimer(
                  key: const ValueKey('normal'),
                  onTimeUpdate: widget.onTimeUpdate,
                  onTimerStart: widget.onTimerStart,
                  onTimerStop: widget.onTimerStop,
                )
              : PomodoroTimer(
                  key: const ValueKey('pomodoro'),
                  onTimeUpdate: widget.onTimeUpdate,
                  onTimerStart: widget.onTimerStart,
                  onTimerStop: widget.onTimerStop,
                ),
        ),
      ],
    );
  }

  Widget _buildModeButton({
    required TimerMode mode,
    required String label,
    required IconData icon,
  }) {
    final isSelected = _currentMode == mode;

    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _switchMode(mode),
          borderRadius: BorderRadius.circular(8.0),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            decoration: BoxDecoration(
              color: isSelected ? Theme.of(context).colorScheme.primary : Colors.transparent,
              borderRadius: BorderRadius.circular(8.0),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 18.0,
                  color: isSelected
                      ? Theme.of(context).colorScheme.onPrimary
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8.0),
                Flexible(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: isSelected
                          ? Theme.of(context).colorScheme.onPrimary
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

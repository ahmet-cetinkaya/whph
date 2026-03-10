import 'package:flutter/material.dart';
import 'package:mediatr/mediatr.dart';
import 'package:acore/acore.dart';
import 'package:whph/infrastructure/shared/features/wakelock/abstractions/i_wakelock_service.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/ui/features/tasks/components/timer/timer_controller.dart';
import 'package:whph/presentation/ui/features/tasks/components/timer/timer_sound_helper.dart';
import 'package:whph/presentation/ui/features/tasks/components/timer/timer_system_tray_helper.dart';
import 'package:whph/presentation/ui/features/tasks/components/timer/timer_ui_helpers.dart';
import 'package:whph/presentation/ui/features/tasks/components/timer_settings_dialog.dart';
import 'package:whph/presentation/ui/features/tasks/constants/task_translation_keys.dart';
import 'package:whph/presentation/ui/shared/constants/app_theme.dart';
import 'package:whph/presentation/ui/shared/constants/shared_ui_constants.dart';
import 'package:whph/presentation/ui/shared/enums/timer_mode.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_notification_service.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_sound_manager_service.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_system_tray_service.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_translation_service.dart';

class AppTimer extends StatefulWidget {
  final void Function(Duration elapsedIncrement)? onTick;
  final VoidCallback? onTimerStart;
  final Function(Duration)? onTimerStop;
  final Function(Duration)? onWorkSessionComplete;
  final bool isMiniLayout;

  const AppTimer({
    super.key,
    this.onTick,
    this.onTimerStart,
    this.onTimerStop,
    this.onWorkSessionComplete,
    this.isMiniLayout = false,
  });

  @override
  State<AppTimer> createState() => _AppTimerState();
}

class _AppTimerState extends State<AppTimer> {
  late final TimerController _controller;
  late final TimerSystemTrayHelper _systemTrayHelper;
  late final TimerSoundHelper _soundHelper;
  late final IWakelockService _wakelockService;
  late final INotificationService _notificationService;
  late final ITranslationService _translationService;

  @override
  void initState() {
    super.initState();
    _initializeServices();
    _controller.initializeSettings();
  }

  void _initializeServices() {
    final mediator = container.resolve<Mediator>();
    final soundManagerService = container.resolve<ISoundManagerService>();
    final systemTrayService = container.resolve<ISystemTrayService>();
    _translationService = container.resolve<ITranslationService>();
    _notificationService = container.resolve<INotificationService>();
    _wakelockService = container.resolve<IWakelockService>();

    _controller = TimerController(mediator: mediator);
    _soundHelper = TimerSoundHelper(soundManagerService: soundManagerService);
    _systemTrayHelper = TimerSystemTrayHelper(
      systemTrayService: systemTrayService,
      translationService: _translationService,
    );

    _setupControllerCallbacks();
  }

  void _setupControllerCallbacks() {
    _controller.onTimerStarted = _handleTimerStarted;
    _controller.onTimerStopped = _handleTimerStopped;
    _controller.onWorkSessionComplete = widget.onWorkSessionComplete;
    _controller.onTick = _handleTick;
    _controller.onAlarmStart = _handleAlarmStart;
    _controller.onAlarmStop = _handleAlarmStop;
  }

  void _handleTimerStarted() {
    widget.onTimerStart?.call();
    _soundHelper.playControlSound();
    _systemTrayHelper.setIcon(isWorking: _controller.isWorking);
    _systemTrayHelper.addMenuItems(onStopTimer: _controller.stopTimer);
    _updateSystemTrayTimer();

    if (_controller.tickingEnabled) {
      _soundHelper.startTicking(
        isEnabled: true,
        tickingSpeed: _controller.tickingSpeed,
        isRunning: _controller.isRunning,
      );
    }

    if (_controller.keepScreenAwake) {
      _wakelockService.enable();
    }
  }

  void _handleTimerStopped(Duration elapsed) {
    _soundHelper.stopTicking();
    _soundHelper.stopAll();
    _soundHelper.playControlSound();
    _wakelockService.disable();
    _systemTrayHelper.resetIcon();
    _systemTrayHelper.removeMenuItems();
    _systemTrayHelper.resetToDefault();
    widget.onTimerStop?.call(elapsed);
  }

  void _handleTick(Duration elapsedIncrement) {
    widget.onTick?.call(elapsedIncrement);
    _updateSystemTrayTimer();
  }

  void _handleAlarmStart() {
    _soundHelper.stopTicking();
    _soundHelper.startAlarm();
    _sendNotification();
  }

  void _handleAlarmStop() {
    _soundHelper.stopAlarm();
  }

  void _updateSystemTrayTimer() {
    final timeDisplay = TimerUiHelpers.getDisplayTime(
      context: context,
      timerMode: _controller.timerMode,
      elapsedTime: _controller.elapsedTime,
      remainingTime: _controller.remainingTime,
    );

    _systemTrayHelper.updateTimerNotification(
      isWorking: _controller.isWorking,
      isLongBreak: _controller.isLongBreak,
      timeDisplay: timeDisplay,
    );
  }

  void _sendNotification() {
    final completionMessage = _controller.isWorking
        ? _translationService.translate(TaskTranslationKeys.pomodoroWorkSessionCompleted)
        : _translationService.translate(_controller.isLongBreak
            ? TaskTranslationKeys.pomodoroLongBreakSessionCompleted
            : TaskTranslationKeys.pomodoroBreakSessionCompleted);

    _systemTrayHelper.setCompletionNotification(
      isWorking: _controller.isWorking,
      isLongBreak: _controller.isLongBreak,
    );

    _notificationService.show(
      title: _translationService.translate(TaskTranslationKeys.pomodoroNotificationTitle),
      body: completionMessage,
    );
  }

  @override
  void dispose() {
    _soundHelper.dispose();
    _wakelockService.disable();

    if (_systemTrayHelper.isTimerMenuAdded) {
      _systemTrayHelper.removeMenuItems();
    }
    _systemTrayHelper.resetToDefault();

    _controller.dispose();
    super.dispose();
  }

  Future<void> _showSettingsModal() async {
    await ResponsiveDialogHelper.showResponsiveDialog(
      context: context,
      size: DialogSize.xLarge,
      child: TimerSettingsDialog(
        initialTimerMode: _controller.timerMode,
        initialWorkDuration: _controller.workDuration,
        initialBreakDuration: _controller.breakDuration,
        initialLongBreakDuration: _controller.longBreakDuration,
        initialSessionsCount: _controller.sessionsCount,
        initialAutoStartBreak: _controller.autoStartBreak,
        initialAutoStartWork: _controller.autoStartWork,
        initialTickingEnabled: _controller.tickingEnabled,
        initialKeepScreenAwake: _controller.keepScreenAwake,
        initialTickingVolume: _controller.tickingVolume,
        initialTickingSpeed: _controller.tickingSpeed,
        onSettingsChanged: _handleSettingsChanged,
      ),
    );
  }

  Future<void> _handleSettingsChanged(
    TimerMode timerMode,
    int workDuration,
    int breakDuration,
    int longBreakDuration,
    int sessionsCount,
    bool autoStartBreak,
    bool autoStartWork,
    bool tickingEnabled,
    bool keepScreenAwake,
    int tickingVolume,
    int tickingSpeed,
  ) async {
    await _controller.saveSetting('work_time', workDuration);
    await _controller.saveSetting('break_time', breakDuration);
    await _controller.saveSetting('long_break_time', longBreakDuration);
    await _controller.saveSetting('sessions_before_long_break', sessionsCount);

    _controller.updateSettings(
      timerMode: timerMode,
      workDuration: workDuration,
      breakDuration: breakDuration,
      longBreakDuration: longBreakDuration,
      sessionsCount: sessionsCount,
      autoStartBreak: autoStartBreak,
      autoStartWork: autoStartWork,
      tickingEnabled: tickingEnabled,
      keepScreenAwake: keepScreenAwake,
      tickingVolume: tickingVolume,
      tickingSpeed: tickingSpeed,
    );
  }

  VoidCallback _getButtonAction() {
    if (_controller.isAlarmPlaying) {
      if (_controller.timerMode.isStopwatchOrNormal) {
        return _controller.stopTimer;
      }
      return _controller.toggleWorkBreak;
    }
    if (_controller.isRunning) return _controller.stopTimer;
    return _controller.startTimer;
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) => _buildTimerWidget(context),
    );
  }

  Widget _buildTimerWidget(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isActive = _controller.isRunning || _controller.isAlarmPlaying;

    final double multiplier = widget.isMiniLayout ? 1.0 : (!isActive ? 1.0 : 2.0);
    final double baseButtonSize = widget.isMiniLayout ? AppTheme.iconSizeSmall : AppTheme.iconSizeLarge;
    final double baseSpacing =
        widget.isMiniLayout ? AppTheme.size2XSmall : (screenWidth < 600 ? AppTheme.sizeSmall : AppTheme.sizeLarge);
    final double buttonSize = baseButtonSize * multiplier;
    final double spacing = baseSpacing * multiplier;

    final progress = TimerUiHelpers.calculateProgress(
      timerMode: _controller.timerMode,
      isRunning: _controller.isRunning,
      isAlarmPlaying: _controller.isAlarmPlaying,
      remainingTime: _controller.remainingTime,
      totalDurationInSeconds: _controller.getTotalDurationInSeconds(),
    );

    final backgroundColor = widget.isMiniLayout
        ? Colors.transparent
        : TimerUiHelpers.getBackgroundColor(
            timerMode: _controller.timerMode,
            isRunning: _controller.isRunning,
            isAlarmPlaying: _controller.isAlarmPlaying,
            isWorking: _controller.isWorking,
            isLongBreak: _controller.isLongBreak,
          );

    final progressBarColor = TimerUiHelpers.getProgressBarColor(
      timerMode: _controller.timerMode,
      isRunning: _controller.isRunning,
      isAlarmPlaying: _controller.isAlarmPlaying,
      isWorking: _controller.isWorking,
      isLongBreak: _controller.isLongBreak,
    );

    final buttonIcon = TimerUiHelpers.getButtonIcon(
      timerMode: _controller.timerMode,
      isAlarmPlaying: _controller.isAlarmPlaying,
      isRunning: _controller.isRunning,
    );

    final displayTime = TimerUiHelpers.getDisplayTime(
      context: context,
      timerMode: _controller.timerMode,
      elapsedTime: _controller.elapsedTime,
      remainingTime: _controller.remainingTime,
    );

    return AnimatedContainer(
      duration: widget.isMiniLayout ? Duration.zero : const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      padding: EdgeInsets.zero,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(buttonSize),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (!widget.isMiniLayout)
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(buttonSize),
                child: LinearProgressIndicator(
                  value: progress,
                  backgroundColor: Colors.transparent,
                  valueColor: AlwaysStoppedAnimation<Color>(progressBarColor),
                  minHeight: buttonSize * 2,
                ),
              ),
            ),
          Padding(
            padding: widget.isMiniLayout ? EdgeInsets.zero : const EdgeInsets.all(AppTheme.sizeMedium),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              spacing: spacing,
              children: [
                if (!isActive)
                  IconButton(
                    iconSize: buttonSize,
                    icon: Icon(SharedUiConstants.settingsIcon),
                    onPressed: _showSettingsModal,
                  ),
                AnimatedDefaultTextStyle(
                  textAlign: TextAlign.center,
                  duration: widget.isMiniLayout ? Duration.zero : const Duration(milliseconds: 300),
                  style: widget.isMiniLayout
                      ? AppTheme.bodyMedium
                      : (isActive ? AppTheme.displayLarge : AppTheme.headlineMedium),
                  child: Text(
                    displayTime,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                ),
                IconButton(
                  iconSize: buttonSize,
                  icon: Icon(buttonIcon),
                  onPressed: _getButtonAction(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

extension on TimerMode {
  bool get isStopwatchOrNormal => this == TimerMode.stopwatch || this == TimerMode.normal;
}

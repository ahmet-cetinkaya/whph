import 'package:flutter/material.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/core/application/features/settings/queries/get_setting_query.dart';
import 'package:whph/core/domain/features/settings/setting.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/ui/shared/constants/setting_keys.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/presentation/ui/features/settings/constants/settings_translation_keys.dart';
import 'package:whph/presentation/ui/shared/components/loading_overlay.dart';
import 'package:whph/presentation/ui/shared/components/responsive_scaffold_layout.dart';
import 'package:whph/presentation/ui/shared/utils/async_error_handler.dart';
import 'package:whph/presentation/ui/features/settings/components/habit_settings/habit_three_state_setting.dart';
import 'package:whph/presentation/ui/features/settings/components/habit_settings/habit_reverse_day_order_setting.dart';

class HabitSettings extends StatefulWidget {
  final VoidCallback? onLoaded;

  const HabitSettings({
    super.key,
    this.onLoaded,
  });

  @override
  State<HabitSettings> createState() => _HabitSettingsState();
}

class _HabitSettingsState extends State<HabitSettings> {
  final _mediator = container.resolve<Mediator>();
  final _translationService = container.resolve<ITranslationService>();

  bool _isLoading = true;
  bool _threeStateEnabled = false;
  bool _reverseDayOrder = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    await AsyncErrorHandler.executeWithLoading(
      context: context,
      setLoading: (isLoading) => setState(() {
        _isLoading = isLoading;
      }),
      errorMessage: _translationService.translate('settings.habit.load_error'),
      operation: () async {
        try {
          final setting = await _mediator.send<GetSettingQuery, Setting?>(
            GetSettingQuery(key: SettingKeys.habitThreeStateEnabled),
          );

          if (setting != null) {
            _threeStateEnabled = setting.getValue<bool>();
          } else {
            _threeStateEnabled = false; // Default to false
          }

          final reverseOrderSetting = await _mediator.send<GetSettingQuery, Setting?>(
            GetSettingQuery(key: SettingKeys.habitReverseDayOrder),
          );

          if (reverseOrderSetting != null) {
            _reverseDayOrder = reverseOrderSetting.getValue<bool>();
          } else {
            _reverseDayOrder = false; // Default to false
          }
        } catch (_) {
          _threeStateEnabled = false;
          _reverseDayOrder = false;
        }

        setState(() {});
        return true;
      },
      onSuccess: (_) {
        widget.onLoaded?.call();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return ResponsiveScaffoldLayout(
      title: _translationService.translate(SettingsTranslationKeys.habitSettingsTitle),
      showBackButton: true,
      hideSidebar: true,
      showLogo: false,
      builder: (context) => LoadingOverlay(
        isLoading: _isLoading,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              HabitThreeStateSetting(
                initialValue: _threeStateEnabled,
              ),
              const SizedBox(height: 16),
              HabitReverseDayOrderSetting(
                initialValue: _reverseDayOrder,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

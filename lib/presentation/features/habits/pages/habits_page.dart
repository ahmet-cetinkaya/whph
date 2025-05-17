import 'package:flutter/material.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/features/habits/components/habit_add_button.dart';
import 'package:whph/presentation/features/habits/components/habit_filters.dart';
import 'package:whph/presentation/features/habits/components/habits_list.dart';
import 'package:whph/presentation/features/habits/pages/habit_details_page.dart';
import 'package:whph/presentation/features/habits/services/habits_service.dart';
import 'package:whph/presentation/shared/constants/app_theme.dart';
import 'package:whph/presentation/shared/constants/shared_translation_keys.dart';
import 'package:whph/presentation/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/presentation/shared/utils/app_theme_helper.dart';
import 'package:whph/core/acore/time/date_time_helper.dart';
import 'package:whph/presentation/shared/components/responsive_scaffold_layout.dart';
import 'package:whph/presentation/shared/models/dropdown_option.dart';
import 'package:whph/presentation/shared/components/help_menu.dart';
import 'package:whph/presentation/features/habits/constants/habit_translation_keys.dart';
import 'package:whph/presentation/shared/utils/responsive_dialog_helper.dart';

class HabitsPage extends StatefulWidget {
  static const String route = '/habits';

  const HabitsPage({super.key});

  @override
  State<HabitsPage> createState() => _HabitsPageState();
}

class _HabitsPageState extends State<HabitsPage> {
  final _translationService = container.resolve<ITranslationService>();
  final _habitsService = container.resolve<HabitsService>();

  List<String> _selectedFilterTags = [];
  bool _showNoTagsFilter = false;
  String? _handledHabitId; // Track the habit ID that we've already handled

  Future<void> _openDetails(String habitId, BuildContext context) async {
    await ResponsiveDialogHelper.showResponsiveDialog(
      context: context,
      title: _translationService.translate(HabitTranslationKeys.helpTitle),
      child: HabitDetailsPage(
        habitId: habitId,
      ),
    );
    // No need to manually refresh - HabitsList will automatically refresh via event listeners
  }

  void _onFilterTagsSelect(List<DropdownOption<String>> tagOptions, bool isNoneSelected) {
    if (!mounted) return;

    // Update state with new filter values
    setState(() {
      _selectedFilterTags = tagOptions.isEmpty ? [] : tagOptions.map((option) => option.value).toList();
      _showNoTagsFilter = isNoneSelected;
    });

    // HabitsList will detect filter changes via didUpdateWidget
  }

  Widget _buildCalendarDay(DateTime date, DateTime today) {
    final bool isToday = DateTimeHelper.isSameDay(date, today);
    final color = isToday ? AppTheme.primaryColor : AppTheme.textColor;

    return SizedBox(
      width: 46,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            _translationService.translate(SharedTranslationKeys.getWeekDayKey(date.weekday)),
            style: AppTheme.bodySmall.copyWith(color: color),
          ),
          Text(
            date.day.toString(),
            style: AppTheme.bodySmall.copyWith(color: color),
          )
        ],
      ),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Check if we have arguments to show habit details
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map<String, dynamic> && (args.containsKey('habitId'))) {
      final habitId = args['habitId'] as String;

      // Only handle the habit if we haven't already handled it
      if (_handledHabitId != habitId) {
        _handledHabitId = habitId;

        // Schedule the dialog to open after the build is complete
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _openDetails(habitId, context);
          }
        });
      }
    } else {
      // Check if we have a route name that includes a habit ID
      final routeName = ModalRoute.of(context)?.settings.name;
      if (routeName != null && routeName.startsWith('/habits/') && routeName != '/habits/details') {
        final habitId = routeName.substring('/habits/'.length);

        // Only handle the habit if we haven't already handled it
        if (_handledHabitId != habitId) {
          _handledHabitId = habitId;

          // Schedule the dialog to open after the build is complete
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              _openDetails(habitId, context);
            }
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    int daysToShow = 7;

    if (AppThemeHelper.isScreenSmallerThan(context, AppTheme.screenSmall)) {
      daysToShow = 1;
    } else if (AppThemeHelper.isScreenSmallerThan(context, AppTheme.screenMedium)) {
      daysToShow = 2;
    } else if (AppThemeHelper.isScreenSmallerThan(context, AppTheme.screenLarge)) {
      daysToShow = 4;
    }

    List<DateTime> lastDays = List.generate(daysToShow, (index) => today.subtract(Duration(days: index)));

    return ResponsiveScaffoldLayout(
      title: _translationService.translate(HabitTranslationKeys.pageTitle),
      appBarActions: [
        HabitAddButton(
          onHabitCreated: (String habitId) {
            if (!mounted) return;

            // Notify the service that a habit was created
            _habitsService.notifyHabitCreated(habitId);

            _openDetails(habitId, context);
          },
          buttonColor: AppTheme.primaryColor,
        ),
        HelpMenu(
          titleKey: HabitTranslationKeys.overviewHelpTitle,
          markdownContentKey: HabitTranslationKeys.overviewHelpContent,
        ),
        const SizedBox(width: 8),
      ],
      builder: (context) => ListView(
        children: [
          // Filters and Calendar row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Filter by tags
              HabitFilters(
                selectedTagIds: _selectedFilterTags.isEmpty ? null : _selectedFilterTags,
                onTagFilterChange: _onFilterTagsSelect,
              ),

              // Calendar
              if (AppThemeHelper.isScreenGreaterThan(context, AppTheme.screenSmall))
                Padding(
                  padding: const EdgeInsets.only(right: AppTheme.sizeMedium),
                  child: SizedBox(
                    width: daysToShow * 46.0,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: lastDays.map((date) => _buildCalendarDay(date, today)).toList(),
                    ),
                  ),
                ),
            ],
          ),

          const SizedBox(height: AppTheme.sizeMedium),

          // List
          HabitsList(
            dateRange: daysToShow,
            filterByTags: _selectedFilterTags,
            filterNoTags: _showNoTagsFilter,
            onClickHabit: (item) {
              _openDetails(item.id, context);
            },
          ),
        ],
      ),
    );
  }
}

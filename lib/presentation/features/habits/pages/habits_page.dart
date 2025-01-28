import 'package:flutter/material.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/features/habits/components/habit_add_button.dart';
import 'package:whph/presentation/features/habits/components/habits_list.dart';
import 'package:whph/presentation/features/habits/pages/habit_details_page.dart';
import 'package:whph/presentation/shared/constants/app_theme.dart';
import 'package:whph/presentation/shared/constants/shared_translation_keys.dart';
import 'package:whph/presentation/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/presentation/shared/utils/app_theme_helper.dart';
import 'package:whph/presentation/shared/utils/date_time_helper.dart';
import 'package:whph/presentation/features/tags/components/tag_select_dropdown.dart';
import 'package:whph/presentation/shared/components/responsive_scaffold_layout.dart';
import 'package:whph/presentation/shared/models/dropdown_option.dart';
import 'package:whph/presentation/shared/components/help_menu.dart';
import 'package:whph/presentation/features/habits/constants/habit_translation_keys.dart';

class HabitsPage extends StatefulWidget {
  static const String route = '/habits';
  final Mediator mediator = container.resolve<Mediator>();

  HabitsPage({super.key});

  @override
  State<HabitsPage> createState() => _HabitsPageState();
}

class _HabitsPageState extends State<HabitsPage> {
  final _translationService = container.resolve<ITranslationService>();
  Key _habitsListKey = UniqueKey();
  List<String> _selectedFilterTags = [];

  void _refreshHabitsList() {
    if (mounted) {
      setState(() {
        _habitsListKey = UniqueKey();
      });
    }
  }

  Future<void> _openDetails(String habitId, BuildContext context) async {
    await Navigator.of(context).pushNamed(
      HabitDetailsPage.route,
      arguments: {'id': habitId},
    );
    _refreshHabitsList();
  }

  void _onFilterTagsSelect(List<DropdownOption<String>> tagOptions) {
    if (mounted) {
      setState(() {
        _selectedFilterTags = tagOptions.map((option) => option.value).toList();
        _refreshHabitsList();
      });
    }
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
            _openDetails(habitId, context);
          },
          buttonColor: AppTheme.primaryColor,
        ),
        HelpMenu(
          titleKey: HabitTranslationKeys.overviewHelpTitle,
          markdownContentKey: HabitTranslationKeys.overviewHelpContent,
        ),
        const SizedBox(width: 2),
      ],
      builder: (context) => Padding(
        padding: const EdgeInsets.all(8),
        child: ListView(
          key: _habitsListKey,
          children: [
            // Filters
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Filter by tags
                TagSelectDropdown(
                  isMultiSelect: true,
                  onTagsSelected: _onFilterTagsSelect,
                  icon: Icons.label,
                  iconSize: AppTheme.iconSizeSmall,
                  color: _selectedFilterTags.isNotEmpty ? AppTheme.primaryColor : Colors.grey,
                  tooltip: _translationService.translate(HabitTranslationKeys.filterByTagsTooltip),
                  showLength: true,
                ),

                // Calendar
                if (AppThemeHelper.isScreenGreaterThan(context, AppTheme.screenSmall))
                  Padding(
                    padding: const EdgeInsets.only(right: 12),
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

            // List
            HabitsList(
              key: _habitsListKey,
              mediator: widget.mediator,
              dateRange: daysToShow,
              filterByTags: _selectedFilterTags,
              onClickHabit: (item) {
                _openDetails(item.id, context);
              },
            ),
          ],
        ),
      ),
    );
  }
}

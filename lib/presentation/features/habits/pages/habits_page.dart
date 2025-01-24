import 'package:flutter/material.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/features/habits/components/habit_add_button.dart';
import 'package:whph/presentation/features/habits/components/habits_list.dart';
import 'package:whph/presentation/features/habits/pages/habit_details_page.dart';
import 'package:whph/presentation/shared/constants/app_theme.dart';
import 'package:whph/presentation/shared/utils/app_theme_helper.dart';
import 'package:whph/presentation/shared/utils/date_time_helper.dart';
import 'package:whph/presentation/features/tags/components/tag_select_dropdown.dart';
import 'package:whph/presentation/shared/components/responsive_scaffold_layout.dart';
import 'package:whph/presentation/shared/models/dropdown_option.dart';

class HabitsPage extends StatefulWidget {
  static const String route = '/habits';
  final Mediator mediator = container.resolve<Mediator>();

  HabitsPage({super.key});

  @override
  State<HabitsPage> createState() => _HabitsPageState();
}

class _HabitsPageState extends State<HabitsPage> {
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
      title: 'Habits',
      appBarActions: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: HabitAddButton(
            onHabitCreated: (String habitId) {
              if (!mounted) return;
              _openDetails(habitId, context);
            },
            buttonColor: AppTheme.primaryColor,
          ),
        ),
      ],
      builder: (context) => Padding(
        padding: const EdgeInsets.all(8),
        child: ListView(
          key: _habitsListKey,
          children: [
            // Filters
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: MediaQuery.of(context).size.width -
                    (AppThemeHelper.isScreenGreaterThan(context, AppTheme.screenMedium) ? 214 : 14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Filter by tags
                    TagSelectDropdown(
                      isMultiSelect: true,
                      onTagsSelected: _onFilterTagsSelect,
                      icon: Icons.label,
                      iconSize: 20,
                      color: _selectedFilterTags.isNotEmpty ? AppTheme.primaryColor : Colors.grey,
                      tooltip: 'Filter by tags',
                      showLength: true,
                    ),

                    // Calendar
                    if (AppThemeHelper.isScreenGreaterThan(context, AppTheme.screenSmall))
                      Padding(
                        padding: const EdgeInsets.only(right: 14),
                        child: SizedBox(
                          width: daysToShow * 46.0,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: lastDays
                                .map(
                                  (date) => SizedBox(
                                    width: 46,
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      crossAxisAlignment: CrossAxisAlignment.center,
                                      children: [
                                        Text(
                                          DateTimeHelper.getWeekday(date.weekday),
                                          style: AppTheme.bodySmall.copyWith(
                                            color: DateTimeHelper.isSameDay(date, today)
                                                ? AppTheme.primaryColor
                                                : AppTheme.textColor,
                                          ),
                                        ),
                                        Text(
                                          date.day.toString(),
                                          style: AppTheme.bodySmall.copyWith(
                                            color: DateTimeHelper.isSameDay(date, today)
                                                ? AppTheme.primaryColor
                                                : AppTheme.textColor,
                                          ),
                                        )
                                      ],
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
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

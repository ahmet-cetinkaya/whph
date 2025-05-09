import 'package:flutter/material.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/features/habits/components/habit_delete_button.dart';
import 'package:whph/presentation/features/habits/components/habit_details_content.dart';
import 'package:whph/presentation/features/habits/services/habits_service.dart';
import 'package:whph/presentation/shared/constants/app_theme.dart';

class HabitDetailsPage extends StatefulWidget {
  static const String route = '/habits/details';
  final String habitId;

  const HabitDetailsPage({super.key, required this.habitId});

  @override
  State<HabitDetailsPage> createState() => _HabitDetailsPageState();
}

class _HabitDetailsPageState extends State<HabitDetailsPage> {
  final _habitsService = container.resolve<HabitsService>();
  bool _isDeleted = false;
  String? _title; // Added for immediate title updates

  @override
  void initState() {
    super.initState();
    _setupEventListeners();
  }

  @override
  void dispose() {
    _removeEventListeners();
    super.dispose();
  }

  void _setupEventListeners() {
    _habitsService.onHabitDeleted.addListener(_handleHabitDeleted);
    _habitsService.onHabitUpdated.addListener(_handleHabitUpdated);
    _habitsService.onHabitRecordAdded.addListener(_handleHabitRecordChanged);
    _habitsService.onHabitRecordRemoved.addListener(_handleHabitRecordChanged);
  }

  void _removeEventListeners() {
    _habitsService.onHabitDeleted.removeListener(_handleHabitDeleted);
    _habitsService.onHabitUpdated.removeListener(_handleHabitUpdated);
    _habitsService.onHabitRecordAdded.removeListener(_handleHabitRecordChanged);
    _habitsService.onHabitRecordRemoved.removeListener(_handleHabitRecordChanged);
  }

  void _handleHabitDeleted() {
    if (!mounted || _habitsService.onHabitDeleted.value != widget.habitId || _isDeleted) return;
    _isDeleted = true;
    Navigator.of(context).pop();
  }

  void _handleHabitUpdated() {
    // We no longer need to load the habit since the HabitDetailsContent
    // will notify us about title changes via onNameUpdated
    if (!mounted || _habitsService.onHabitUpdated.value != widget.habitId) return;
  }

  void _handleHabitRecordChanged() {
    // Records don't affect the title, so no need to reload the habit
    if (!mounted) return;
  }

  void _refreshTitle(String name) {
    if (mounted) {
      setState(() {
        _title = name;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_title ?? ""),
        actions: [
          HabitDeleteButton(
            habitId: widget.habitId,
            buttonColor: AppTheme.primaryColor,
            onDeleteSuccess: () {
              // Only notify the service, navigation will be handled by _handleHabitDeleted
              _habitsService.notifyHabitDeleted(widget.habitId);
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: HabitDetailsContent(
          habitId: widget.habitId,
          onHabitUpdated: () {
            _habitsService.notifyHabitUpdated(widget.habitId);
          },
          onNameUpdated: (name) {
            _refreshTitle(name);
          },
        ),
      ),
    );
  }
}

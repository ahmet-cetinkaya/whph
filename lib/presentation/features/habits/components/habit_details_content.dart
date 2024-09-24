import 'package:flutter/material.dart';
import 'package:markdown_editor_plus/widgets/markdown_auto_preview.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/application/features/habits/commands/save_habit_command.dart';
import 'package:whph/application/features/habits/queries/get_habit_query.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/features/shared/components/header.dart';

class HabitDetailsContent extends StatefulWidget {
  final int habitId;
  final bool isNameFieldVisible;

  const HabitDetailsContent({super.key, required this.habitId, this.isNameFieldVisible = true});

  @override
  State<HabitDetailsContent> createState() => _HabitDetailsContentState();
}

class _HabitDetailsContentState extends State<HabitDetailsContent> {
  final Mediator mediator = container.resolve<Mediator>();

  bool isLoading = false;
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchHabit();
  }

  Future<void> _fetchHabit() async {
    setState(() {
      isLoading = true;
    });

    var query = GetHabitQuery(id: widget.habitId);
    var response = await mediator.send<GetHabitQuery, GetHabitQueryResponse>(query);
    _nameController.text = response.name;
    _descriptionController.text = response.description;

    setState(() {
      isLoading = false;
    });
  }

  Future<void> _saveHabit() async {
    var command = SaveHabitCommand(
      id: widget.habitId,
      name: _nameController.text,
      description: _descriptionController.text,
    );
    await mediator.send(command);
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Name field
                if (widget.isNameFieldVisible) ...[
                  TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(labelText: 'Habit Name'),
                    onChanged: (value) => _saveHabit(),
                  ),
                  const SizedBox(height: 16.0),
                ],

                // Description field
                const Header(text: 'Description'),
                MarkdownAutoPreview(
                  controller: _descriptionController,
                  emojiConvert: true,
                  onChanged: (value) => _saveHabit(),
                  minLines: 1,
                ),
                const SizedBox(height: 16.0),
              ],
            ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }
}

import 'package:flutter/material.dart';
import 'package:whph/presentation/shared/constants/app_theme.dart';
import 'package:whph/presentation/shared/utils/error_helper.dart';
import 'package:whph/presentation/features/tags/components/tag_select_dropdown.dart';
import 'package:whph/presentation/shared/models/dropdown_option.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/application/features/app_usages/commands/add_app_usage_tag_rule_command.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/shared/components/regex_help_dialog.dart';

class AppUsageTagRuleForm extends StatefulWidget {
  final Function() onSave;
  final VoidCallback? onCancel;

  const AppUsageTagRuleForm({
    super.key,
    required this.onSave,
    this.onCancel,
  });

  @override
  State<AppUsageTagRuleForm> createState() => _AppUsageTagRuleFormState();
}

class _AppUsageTagRuleFormState extends State<AppUsageTagRuleForm> {
  final _formKey = GlobalKey<FormState>();
  var _tagDropdownKey = UniqueKey();
  final _patternController = TextEditingController();
  final _descriptionController = TextEditingController();
  DropdownOption<String>? _selectedTag;
  bool _showValidationErrors = false;
  final Mediator _mediator = container.resolve<Mediator>();

  @override
  void dispose() {
    _patternController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _resetForm() {
    _formKey.currentState?.reset();
    _tagDropdownKey = UniqueKey();

    // Then clear controllers after a small delay to ensure UI updates
    Future.microtask(() {
      if (mounted) {
        setState(() {
          _patternController.clear();
          _descriptionController.clear();
          _selectedTag = null;
          _showValidationErrors = false;
        });
      }
    });
  }

  Future<void> _handleSubmit() async {
    setState(() {
      _showValidationErrors = true;
    });

    if (_formKey.currentState!.validate() && _selectedTag != null) {
      try {
        final command = AddAppUsageTagRuleCommand(
          pattern: _patternController.text,
          tagId: _selectedTag!.value,
          description: _descriptionController.text.isEmpty ? null : _descriptionController.text,
          isActive: true,
        );

        await _mediator.send<AddAppUsageTagRuleCommand, AddAppUsageTagRuleCommandResponse>(command);

        if (mounted) {
          widget.onSave();
          _resetForm();
        }
      } catch (e, stackTrace) {
        if (!mounted) return;
        ErrorHelper.showUnexpectedError(context, e as Exception, stackTrace,
            message: 'Unexpected error occurred while adding app usage tag rule.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      autovalidateMode: _showValidationErrors ? AutovalidateMode.always : AutovalidateMode.disabled,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Pattern Field
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _patternController,
                      decoration: InputDecoration(
                        labelText: 'Pattern',
                        labelStyle: const TextStyle(fontSize: 12),
                        hintText: 'e.g., .*Chrome.*',
                        hintStyle: const TextStyle(
                          fontSize: 11,
                          fontFamily: 'monospace',
                        ),
                        prefixIcon: const Icon(Icons.pattern, size: 18),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        errorStyle: const TextStyle(height: 0.7, fontSize: 10),
                        errorBorder: _showValidationErrors && _patternController.text.isEmpty
                            ? OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide(color: Theme.of(context).colorScheme.error),
                              )
                            : null,
                      ),
                      style: const TextStyle(
                        fontSize: 14,
                        fontFamily: 'monospace',
                      ),
                      validator: (value) => (value?.isEmpty ?? true) ? 'Pattern is required' : null,
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 32,
                    height: 32,
                    child: IconButton(
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints: BoxConstraints(minWidth: 32),
                      icon: const Icon(Icons.help_outline, size: 18),
                      tooltip: 'Pattern Help',
                      onPressed: () => RegexHelpDialog.show(context),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Tag Selection Field
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 36,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: AppTheme.surface2,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: _showValidationErrors && _selectedTag == null
                              ? Theme.of(context).colorScheme.error
                              : Colors.transparent,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.label,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _selectedTag?.label ?? 'Select a tag',
                              style: TextStyle(
                                color: _selectedTag != null
                                    ? Theme.of(context).textTheme.bodyMedium?.color
                                    : Theme.of(context).hintColor,
                                fontSize: 11,
                              ),
                            ),
                          ),
                          if (_selectedTag != null)
                            IconButton(
                              icon: const Icon(
                                Icons.close,
                                size: 16,
                                color: Colors.grey,
                              ),
                              onPressed: () => setState(() => _selectedTag = null),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  TagSelectDropdown(
                    key: _tagDropdownKey,
                    onTagsSelected: (options) => setState(() => _selectedTag = options.first),
                    isMultiSelect: false,
                    limit: 1,
                    icon: _selectedTag == null ? Icons.add : Icons.edit,
                    iconSize: 18,
                    color: _selectedTag != null ? Theme.of(context).primaryColor : null,
                  ),
                ],
              ),
              if (_showValidationErrors && _selectedTag == null)
                Padding(
                  padding: const EdgeInsets.only(top: 4, left: 12),
                  child: Text(
                    'Tag is required',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                      fontSize: 12,
                    ),
                  ),
                ),
            ],
          ),

          const SizedBox(height: 12),

          // Description Field
          TextFormField(
            controller: _descriptionController,
            decoration: const InputDecoration(
              labelText: 'Description (Optional)',
              labelStyle: TextStyle(fontSize: 12),
              hintText: 'Enter description for this rule',
              hintStyle: TextStyle(fontSize: 11),
              prefixIcon: Icon(Icons.description, size: 18),
              isDense: true,
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              constraints: BoxConstraints(maxHeight: 36),
            ),
            style: const TextStyle(fontSize: 12),
            maxLines: 1,
          ),
          const SizedBox(height: 16),

          // Action Buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (widget.onCancel != null)
                TextButton.icon(
                  onPressed: widget.onCancel,
                  icon: const Icon(Icons.close, size: 18, color: AppTheme.darkTextColor),
                  label: const Text('Cancel', style: TextStyle(fontSize: 12, color: AppTheme.darkTextColor)),
                ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: _handleSubmit,
                icon: const Icon(Icons.add, size: 18, color: AppTheme.darkTextColor),
                label: const Text('Add', style: TextStyle(fontSize: 12, color: AppTheme.darkTextColor)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

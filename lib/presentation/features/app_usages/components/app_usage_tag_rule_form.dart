import 'package:flutter/material.dart';
import 'package:whph/presentation/shared/constants/app_theme.dart';
import 'package:whph/presentation/shared/constants/shared_ui_constants.dart';
import 'package:whph/presentation/shared/utils/error_helper.dart';
import 'package:whph/presentation/features/tags/components/tag_select_dropdown.dart';
import 'package:whph/presentation/shared/models/dropdown_option.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/application/features/app_usages/commands/add_app_usage_tag_rule_command.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/shared/components/regex_help_dialog.dart';
import 'package:whph/presentation/features/app_usages/constants/app_usage_ui_constants.dart';
import 'package:whph/presentation/features/app_usages/constants/app_usage_translation_keys.dart';
import 'package:whph/presentation/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/presentation/shared/constants/shared_translation_keys.dart';

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
  final _translationService = container.resolve<ITranslationService>();
  bool _isSaved = false;

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
        );

        await _mediator.send<AddAppUsageTagRuleCommand, AddAppUsageTagRuleCommandResponse>(command);

        if (mounted) {
          widget.onSave();
          setState(() {
            _isSaved = true;
          });
          _resetForm();

          await Future.delayed(const Duration(seconds: 2));
          if (mounted) {
            setState(() {
              _isSaved = false;
            });
          }
        }
      } catch (e, stackTrace) {
        if (!mounted) return;
        ErrorHelper.showUnexpectedError(
          context,
          e as Exception,
          stackTrace,
          message: _translationService.translate(AppUsageTranslationKeys.saveRuleError),
        );
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Pattern Field
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _patternController,
                      decoration: InputDecoration(
                        labelText: _translationService.translate(AppUsageTranslationKeys.patternFieldLabel),
                        labelStyle: AppTheme.bodySmall,
                        hintText: _translationService.translate(AppUsageTranslationKeys.patternFieldHint),
                        hintStyle: AppTheme.bodySmall.copyWith(fontFamily: 'monospace'),
                        prefixIcon: Icon(AppUsageUiConstants.patternIcon, size: AppTheme.iconSizeSmall),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        errorStyle: TextStyle(height: 0.7, fontSize: AppTheme.fontSizeXSmall),
                        errorBorder: _showValidationErrors && _patternController.text.isEmpty
                            ? OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide(color: Theme.of(context).colorScheme.error),
                              )
                            : null,
                      ),
                      style: AppTheme.bodyMedium.copyWith(fontFamily: 'monospace'),
                      validator: (value) => (value?.isEmpty ?? true)
                          ? _translationService.translate(AppUsageTranslationKeys.patternFieldRequired)
                          : null,
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 32,
                    height: 32,
                    child: IconButton(
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 32),
                      icon: Icon(AppUsageUiConstants.helpIcon, size: AppTheme.iconSizeSmall),
                      tooltip: _translationService.translate(AppUsageTranslationKeys.patternFieldHelpTooltip),
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
                        color: AppTheme.surface1,
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
                            size: AppTheme.fontSizeLarge,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _selectedTag?.label ?? _translationService.translate(AppUsageTranslationKeys.tagsHint),
                              style: AppTheme.bodySmall.copyWith(
                                color: _selectedTag != null
                                    ? Theme.of(context).textTheme.bodyMedium?.color
                                    : Theme.of(context).hintColor,
                              ),
                            ),
                          ),
                          if (_selectedTag != null)
                            IconButton(
                              icon: const Icon(
                                Icons.close,
                                size: AppTheme.fontSizeLarge,
                                color: Colors.grey,
                              ),
                              onPressed: () => setState(() => _selectedTag = null),
                            ),
                        ],
                      ),
                    ),
                  ),
                  TagSelectDropdown(
                    key: _tagDropdownKey,
                    onTagsSelected: (options) => setState(() => _selectedTag = options.first),
                    isMultiSelect: false,
                    limit: 1,
                    icon: _selectedTag == null ? Icons.add : Icons.edit,
                    iconSize: AppTheme.iconSizeSmall,
                    color: _selectedTag != null ? Theme.of(context).primaryColor : null,
                  ),
                ],
              ),
              if (_showValidationErrors && _selectedTag == null)
                Padding(
                  padding: const EdgeInsets.only(top: 4, left: 12),
                  child: Text(
                    _translationService.translate(SharedTranslationKeys.requiredValidation,
                        namedArgs: {'field': _translationService.translate(AppUsageTranslationKeys.tagsLabel)}),
                    style: AppTheme.bodySmall.copyWith(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
            ],
          ),

          const SizedBox(height: 12),

          // Description Field
          TextFormField(
            controller: _descriptionController,
            decoration: InputDecoration(
              labelText: _translationService.translate(AppUsageTranslationKeys.descriptionFieldLabel),
              labelStyle: AppTheme.bodySmall,
              hintText: _translationService.translate(AppUsageTranslationKeys.descriptionFieldHint),
              hintStyle: AppTheme.bodySmall,
              prefixIcon: Icon(Icons.description, size: AppTheme.fontSizeMedium),
              isDense: true,
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              constraints: BoxConstraints(maxHeight: 36),
            ),
            style: AppTheme.bodySmall,
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
                  icon: Icon(SharedUiConstants.closeIcon, size: AppTheme.iconSizeSmall, color: AppTheme.darkTextColor),
                  label: Text(_translationService.translate(SharedTranslationKeys.cancelButton),
                      style: AppTheme.bodySmall.copyWith(color: AppTheme.darkTextColor)),
                ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: _handleSubmit,
                icon: Icon(
                  _isSaved ? SharedUiConstants.checkIcon : SharedUiConstants.saveIcon,
                  size: AppTheme.iconSizeSmall,
                  color: AppTheme.darkTextColor,
                ),
                label: Text(
                  _isSaved
                      ? _translationService.translate(SharedTranslationKeys.savedButton)
                      : _translationService.translate(SharedTranslationKeys.saveButton),
                  style: AppTheme.bodySmall.copyWith(color: AppTheme.darkTextColor),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:whph/presentation/ui/features/tags/constants/tag_ui_constants.dart';
import 'package:whph/presentation/ui/shared/constants/app_theme.dart';
import 'package:whph/presentation/ui/shared/constants/shared_ui_constants.dart';
import 'package:whph/presentation/ui/shared/utils/async_error_handler.dart';
import 'package:whph/presentation/ui/features/tags/components/tag_select_dropdown.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/core/application/features/app_usages/commands/add_app_usage_tag_rule_command.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/ui/shared/components/regex_help_dialog.dart';
import 'package:whph/presentation/ui/features/app_usages/constants/app_usage_ui_constants.dart';
import 'package:whph/presentation/ui/features/app_usages/constants/app_usage_translation_keys.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/presentation/ui/shared/constants/shared_translation_keys.dart';
import 'package:whph/presentation/ui/features/app_usages/services/app_usages_service.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_theme_service.dart';
import 'package:acore/acore.dart' hide Container;

class AppUsageTagRuleForm extends StatefulWidget {
  final Function()? onSave;

  const AppUsageTagRuleForm({
    super.key,
    this.onSave,
  });

  @override
  State<AppUsageTagRuleForm> createState() => AppUsageTagRuleFormState();
}

class AppUsageTagRuleFormState extends State<AppUsageTagRuleForm> {
  final _mediator = container.resolve<Mediator>();
  final _translationService = container.resolve<ITranslationService>();
  final _appUsagesService = container.resolve<AppUsagesService>();
  final _themeService = container.resolve<IThemeService>();

  final _formKey = GlobalKey<FormState>();
  final _patternController = TextEditingController();
  final _descriptionController = TextEditingController();
  String? _selectedTagId;
  String? _selectedTagLabel;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _patternController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  bool validate() {
    return _formKey.currentState?.validate() == true && _selectedTagId != null;
  }

  Future<void> reset() async {
    if (_formKey.currentState == null) return;
    _formKey.currentState!.reset();
    _patternController.clear();
    _descriptionController.clear();
    setState(() {
      _selectedTagId = null;
      _selectedTagLabel = null;
    });
  }

  Future<void> refresh() async {
    await reset();
  }

  Future<void> submit() async {
    setState(() {
      _isSubmitting = true;
    });

    if (validate()) {
      await AsyncErrorHandler.execute<AddAppUsageTagRuleCommandResponse>(
        context: context,
        errorMessage: _translationService.translate(AppUsageTranslationKeys.saveRuleError),
        operation: () async {
          final command = AddAppUsageTagRuleCommand(
            pattern: _patternController.text,
            tagId: _selectedTagId!,
            description: _descriptionController.text.isEmpty ? null : _descriptionController.text,
          );
          return await _mediator.send<AddAppUsageTagRuleCommand, AddAppUsageTagRuleCommandResponse>(command);
        },
        onSuccess: (response) {
          if (mounted) {
            // Notify that a new rule was created
            _appUsagesService.notifyAppUsageRuleCreated(response.id);
            widget.onSave?.call();
            refresh();
          }
        },
        finallyAction: () {
          if (mounted) {
            setState(() {
              _isSubmitting = false;
            });
          }
        },
      );
    } else {
      setState(() {
        _isSubmitting = false;
      });
    }
  }

  void _showRegexHelp() {
    RegexHelpDialog.show(context);
  }

  void _clearSelectedTag() {
    setState(() => _selectedTagId = null);
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      autovalidateMode: _isSubmitting ? AutovalidateMode.always : AutovalidateMode.disabled,
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
                        errorBorder: _isSubmitting && _patternController.text.isEmpty
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
                      icon: Icon(SharedUiConstants.helpIcon, size: AppTheme.iconSizeSmall),
                      tooltip: _translationService.translate(AppUsageTranslationKeys.patternFieldHelpTooltip),
                      onPressed: _showRegexHelp,
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
                          color: _isSubmitting && _selectedTagId == null
                              ? Theme.of(context).colorScheme.error
                              : Colors.transparent,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            TagUiConstants.tagIcon,
                            size: AppTheme.fontSizeLarge,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _selectedTagLabel ?? _translationService.translate(AppUsageTranslationKeys.tagsHint),
                              style: AppTheme.bodySmall.copyWith(
                                color: _selectedTagId != null
                                    ? Theme.of(context).textTheme.bodyMedium?.color
                                    : Theme.of(context).hintColor,
                              ),
                            ),
                          ),
                          if (_selectedTagId != null)
                            IconButton(
                              icon: const Icon(
                                Icons.close,
                                size: AppTheme.fontSizeLarge,
                                color: Colors.grey,
                              ),
                              onPressed: _clearSelectedTag,
                            ),
                        ],
                      ),
                    ),
                  ),
                  TagSelectDropdown(
                    key: UniqueKey(),
                    onTagsSelected: (options, _) => setState(() {
                      if (options.isNotEmpty) {
                        _selectedTagId = options.first.value;
                        _selectedTagLabel = options.first.label;
                      }
                    }),
                    isMultiSelect: false,
                    limit: 1,
                    icon: _selectedTagId == null ? Icons.add : SharedUiConstants.editIcon,
                    iconSize: AppTheme.iconSizeSmall,
                    color: _selectedTagId != null ? Theme.of(context).primaryColor : null,
                  ),
                ],
              ),
              if (_isSubmitting && _selectedTagId == null)
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

          const SizedBox(height: AppTheme.sizeMedium),

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
              contentPadding: EdgeInsets.symmetric(horizontal: AppTheme.sizeMedium, vertical: AppTheme.sizeSmall),
              constraints: BoxConstraints(maxHeight: 36),
            ),
            style: AppTheme.bodySmall,
            maxLines: 1,
          ),
          const SizedBox(height: AppTheme.sizeLarge),

          // Action Buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (widget.onSave != null)
                TextButton.icon(
                  onPressed: widget.onSave,
                  icon: Icon(SharedUiConstants.closeIcon,
                      size: AppTheme.iconSizeSmall, color: _themeService.primaryColor),
                  label: Text(_translationService.translate(SharedTranslationKeys.cancelButton),
                      style: AppTheme.bodySmall.copyWith(color: _themeService.primaryColor)),
                ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: submit,
                icon: Icon(
                  _isSubmitting ? SharedUiConstants.checkIcon : SharedUiConstants.saveIcon,
                  size: AppTheme.iconSizeSmall,
                  color: ColorContrastHelper.getContrastingTextColor(_themeService.primaryColor),
                ),
                label: Text(
                  _isSubmitting
                      ? _translationService.translate(SharedTranslationKeys.savedButton)
                      : _translationService.translate(SharedTranslationKeys.saveButton),
                  style: AppTheme.bodySmall
                      .copyWith(color: ColorContrastHelper.getContrastingTextColor(_themeService.primaryColor)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:whph/presentation/shared/constants/app_theme.dart';
import 'package:whph/presentation/shared/constants/shared_ui_constants.dart';
import 'package:whph/presentation/shared/utils/error_helper.dart';
import 'package:whph/presentation/features/tags/components/tag_select_dropdown.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/application/features/app_usages/commands/add_app_usage_tag_rule_command.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/shared/components/regex_help_dialog.dart';
import 'package:whph/presentation/features/app_usages/constants/app_usage_ui_constants.dart';
import 'package:whph/presentation/features/app_usages/constants/app_usage_translation_keys.dart';
import 'package:whph/presentation/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/presentation/shared/constants/shared_translation_keys.dart';

class AppUsageTagRuleForm extends StatefulWidget {
  final _mediator = container.resolve<Mediator>();
  final _translationService = container.resolve<ITranslationService>();
  final Function()? onSave;

  AppUsageTagRuleForm({
    super.key,
    this.onSave,
  });

  @override
  State<AppUsageTagRuleForm> createState() => AppUsageTagRuleFormState();
}

class AppUsageTagRuleFormState extends State<AppUsageTagRuleForm> {
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

  Future<void> refresh() async {
    if (_formKey.currentState == null) return;
    _formKey.currentState!.reset();
    _patternController.clear();
    _descriptionController.clear();
    _selectedTagId = null;
    setState(() {});
  }

  Future<void> _handleSubmit() async {
    setState(() {
      _isSubmitting = true;
    });

    if (_formKey.currentState!.validate() && _selectedTagId != null) {
      try {
        final command = AddAppUsageTagRuleCommand(
          pattern: _patternController.text,
          tagId: _selectedTagId!,
          description: _descriptionController.text.isEmpty ? null : _descriptionController.text,
        );

        await widget._mediator.send<AddAppUsageTagRuleCommand, AddAppUsageTagRuleCommandResponse>(command);

        if (mounted) {
          widget.onSave?.call();
          await refresh();
        }
      } catch (e, stackTrace) {
        if (!mounted) return;
        ErrorHelper.showUnexpectedError(
          context,
          e as Exception,
          stackTrace,
          message: widget._translationService.translate(AppUsageTranslationKeys.saveRuleError),
        );
      } finally {
        if (mounted) {
          setState(() {
            _isSubmitting = false;
          });
        }
      }
    } else {
      setState(() {
        _isSubmitting = false;
      });
    }
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
                        labelText: widget._translationService.translate(AppUsageTranslationKeys.patternFieldLabel),
                        labelStyle: AppTheme.bodySmall,
                        hintText: widget._translationService.translate(AppUsageTranslationKeys.patternFieldHint),
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
                          ? widget._translationService.translate(AppUsageTranslationKeys.patternFieldRequired)
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
                      tooltip: widget._translationService.translate(AppUsageTranslationKeys.patternFieldHelpTooltip),
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
                          color: _isSubmitting && _selectedTagId == null
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
                              _selectedTagLabel ??
                                  widget._translationService.translate(AppUsageTranslationKeys.tagsHint),
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
                              onPressed: () => setState(() => _selectedTagId = null),
                            ),
                        ],
                      ),
                    ),
                  ),
                  TagSelectDropdown(
                    key: UniqueKey(),
                    onTagsSelected: (options, _) => setState(() {
                      _selectedTagId = options.first.value;
                      _selectedTagLabel = options.first.label;
                    }),
                    isMultiSelect: false,
                    limit: 1,
                    icon: _selectedTagId == null ? Icons.add : Icons.edit,
                    iconSize: AppTheme.iconSizeSmall,
                    color: _selectedTagId != null ? Theme.of(context).primaryColor : null,
                  ),
                ],
              ),
              if (_isSubmitting && _selectedTagId == null)
                Padding(
                  padding: const EdgeInsets.only(top: 4, left: 12),
                  child: Text(
                    widget._translationService.translate(SharedTranslationKeys.requiredValidation,
                        namedArgs: {'field': widget._translationService.translate(AppUsageTranslationKeys.tagsLabel)}),
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
              labelText: widget._translationService.translate(AppUsageTranslationKeys.descriptionFieldLabel),
              labelStyle: AppTheme.bodySmall,
              hintText: widget._translationService.translate(AppUsageTranslationKeys.descriptionFieldHint),
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
              if (widget.onSave != null)
                TextButton.icon(
                  onPressed: widget.onSave,
                  icon: Icon(SharedUiConstants.closeIcon, size: AppTheme.iconSizeSmall, color: AppTheme.darkTextColor),
                  label: Text(widget._translationService.translate(SharedTranslationKeys.cancelButton),
                      style: AppTheme.bodySmall.copyWith(color: AppTheme.darkTextColor)),
                ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: _handleSubmit,
                icon: Icon(
                  _isSubmitting ? SharedUiConstants.checkIcon : SharedUiConstants.saveIcon,
                  size: AppTheme.iconSizeSmall,
                  color: AppTheme.darkTextColor,
                ),
                label: Text(
                  _isSubmitting
                      ? widget._translationService.translate(SharedTranslationKeys.savedButton)
                      : widget._translationService.translate(SharedTranslationKeys.saveButton),
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

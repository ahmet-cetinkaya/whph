import 'package:flutter/material.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/core/application/features/app_usages/commands/add_app_usage_ignore_rule_command.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/ui/features/app_usages/constants/app_usage_translation_keys.dart';
import 'package:whph/presentation/ui/features/app_usages/constants/app_usage_ui_constants.dart';
import 'package:whph/presentation/ui/features/app_usages/services/app_usages_service.dart';
import 'package:whph/presentation/ui/shared/components/regex_help_dialog.dart';
import 'package:whph/presentation/ui/shared/constants/app_theme.dart';
import 'package:whph/presentation/ui/shared/constants/shared_translation_keys.dart';
import 'package:whph/presentation/ui/shared/constants/shared_ui_constants.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/presentation/ui/shared/utils/async_error_handler.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_theme_service.dart';
import 'package:acore/acore.dart';

class AppUsageIgnoreRuleForm extends StatefulWidget {
  final Function()? onSave;

  const AppUsageIgnoreRuleForm({
    super.key,
    this.onSave,
  });

  @override
  State<AppUsageIgnoreRuleForm> createState() => AppUsageIgnoreRuleFormState();
}

class AppUsageIgnoreRuleFormState extends State<AppUsageIgnoreRuleForm> {
  final _mediator = container.resolve<Mediator>();
  final _translationService = container.resolve<ITranslationService>();
  final _appUsagesService = container.resolve<AppUsagesService>();
  final _themeService = container.resolve<IThemeService>();

  final _formKey = GlobalKey<FormState>();
  final _patternController = TextEditingController();
  final _descriptionController = TextEditingController();
  bool _isSubmitting = false;

  void _showRegexHelp() {
    RegexHelpDialog.show(context);
  }

  @override
  void dispose() {
    _patternController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  bool validate() {
    return _formKey.currentState?.validate() == true;
  }

  Future<void> reset() async {
    if (_formKey.currentState == null) return;
    _formKey.currentState!.reset();
    _patternController.clear();
    _descriptionController.clear();
  }

  Future<void> refresh() async {
    await reset();
  }

  Future<void> submit() async {
    setState(() {
      _isSubmitting = true;
    });

    if (validate()) {
      await AsyncErrorHandler.executeWithLoading(
        context: context,
        setLoading: (isLoading) => setState(() {
          _isSubmitting = isLoading;
        }),
        errorMessage: _translationService.translate(AppUsageTranslationKeys.saveRuleError),
        operation: () async {
          final command = AddAppUsageIgnoreRuleCommand(
            pattern: _patternController.text,
            description: _descriptionController.text.isEmpty ? null : _descriptionController.text,
          );

          return await _mediator.send<AddAppUsageIgnoreRuleCommand, AddAppUsageIgnoreRuleCommandResponse>(command);
        },
        onSuccess: (response) async {
          _appUsagesService.notifyAppUsageIgnoreRuleUpdated(response.id);
          widget.onSave?.call();
          await refresh();
        },
      );
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
                  IconButton(
                    icon: Icon(SharedUiConstants.helpIcon),
                    iconSize: AppTheme.iconSizeSmall,
                    onPressed: _showRegexHelp,
                    tooltip: _translationService.translate(AppUsageTranslationKeys.patternFieldHelpTooltip),
                  ),
                ],
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

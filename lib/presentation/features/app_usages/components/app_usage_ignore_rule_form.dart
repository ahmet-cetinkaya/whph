import 'package:flutter/material.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/shared/constants/app_theme.dart';
import 'package:whph/presentation/shared/utils/error_helper.dart';
import 'package:whph/presentation/shared/components/regex_help_dialog.dart';
import 'package:whph/presentation/features/app_usages/constants/app_usage_ui_constants.dart';
import 'package:whph/presentation/shared/constants/shared_ui_constants.dart';
import 'package:whph/application/features/app_usages/commands/add_app_usage_ignore_rule_command.dart';
import 'package:whph/presentation/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/presentation/features/app_usages/constants/app_usage_translation_keys.dart';
import 'package:whph/presentation/shared/constants/shared_translation_keys.dart';

class AppUsageIgnoreRuleForm extends StatefulWidget {
  final Function() onSave;
  final VoidCallback? onCancel;

  const AppUsageIgnoreRuleForm({
    super.key,
    required this.onSave,
    this.onCancel,
  });

  @override
  State<AppUsageIgnoreRuleForm> createState() => _AppUsageIgnoreRuleFormState();
}

class _AppUsageIgnoreRuleFormState extends State<AppUsageIgnoreRuleForm> {
  final Mediator _mediator = container.resolve<Mediator>();
  final _formKey = GlobalKey<FormState>();
  final _patternController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _translationService = container.resolve<ITranslationService>();
  bool _showValidationErrors = false;
  bool _isSaved = false;

  @override
  void dispose() {
    _patternController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _resetForm() {
    _formKey.currentState?.reset();
    _patternController.clear();
    _descriptionController.clear();
    setState(() {
      _showValidationErrors = false;
    });
  }

  Future<void> _handleSubmit() async {
    setState(() {
      _showValidationErrors = true;
    });

    if (_formKey.currentState!.validate()) {
      try {
        final command = AddAppUsageIgnoreRuleCommand(
          pattern: _patternController.text,
          description: _descriptionController.text.isEmpty ? null : _descriptionController.text,
        );

        await _mediator.send(command);

        if (mounted) {
          widget.onSave();
          setState(() => _isSaved = true);
          _resetForm();

          await Future.delayed(const Duration(seconds: 2));
          if (mounted) {
            setState(() => _isSaved = false);
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
        children: [
          // Pattern Field
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
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  icon: Icon(AppUsageUiConstants.helpIcon, size: AppTheme.iconSizeSmall),
                  tooltip: _translationService.translate(AppUsageTranslationKeys.patternFieldHelpTooltip),
                  onPressed: () => RegexHelpDialog.show(context),
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
              prefixIcon: Icon(Icons.description, size: AppTheme.iconSizeSmall),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              errorBorder: _showValidationErrors && _descriptionController.text.isEmpty
                  ? OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: Theme.of(context).colorScheme.error),
                    )
                  : null,
            ),
            style: AppTheme.bodySmall,
          ),
          const SizedBox(height: 16),

          // Action Buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (widget.onCancel != null) ...[
                TextButton.icon(
                  onPressed: widget.onCancel,
                  icon: Icon(SharedUiConstants.closeIcon, size: AppTheme.iconSizeSmall),
                  label: Text(_translationService.translate(SharedTranslationKeys.cancelButton),
                      style: AppTheme.bodySmall),
                ),
                const SizedBox(width: 8),
              ],
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

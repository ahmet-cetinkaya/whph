import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/shared/constants/app_theme.dart';
import 'package:whph/presentation/shared/utils/error_helper.dart';
import 'package:whph/presentation/shared/components/regex_help_dialog.dart';
import 'package:whph/application/features/settings/commands/save_setting_command.dart';
import 'package:whph/application/features/settings/queries/get_setting_query.dart';
import 'package:whph/domain/features/settings/constants/settings.dart';
import 'package:whph/domain/features/settings/setting.dart';
import 'package:whph/presentation/features/app_usages/constants/app_usage_ui_constants.dart';

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
  bool _showValidationErrors = false;
  bool _isSaved = false;

  @override
  void initState() {
    super.initState();
    _loadIgnoreRules();
  }

  Future<void> _loadIgnoreRules() async {
    try {
      final query = GetSettingQuery(key: Settings.appUsageIgnoreList);
      final response = await _mediator.send<GetSettingQuery, GetSettingQueryResponse>(query);

      if (mounted) {
        setState(() {
          _patternController.text = response.value;
        });
      }
    } catch (e) {
      if (kDebugMode) print('ERROR: No ignore rules found: ${e.toString()}');
    }
  }

  @override
  void dispose() {
    _patternController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    setState(() {
      _showValidationErrors = true;
    });

    if (_formKey.currentState!.validate()) {
      try {
        final patterns =
            _patternController.text.split('\n').where((line) => line.trim().isNotEmpty).map((e) => e.trim()).toList();

        final command = SaveSettingCommand(
          key: Settings.appUsageIgnoreList,
          value: patterns.join('\n'),
          valueType: SettingValueType.string,
        );

        await _mediator.send<SaveSettingCommand, SaveSettingCommandResponse>(command);

        if (mounted) {
          setState(() => _isSaved = true);
          widget.onSave();

          Future.delayed(const Duration(seconds: 2), () {
            if (mounted) {
              setState(() => _isSaved = false);
            }
          });
        }
      } catch (e, stackTrace) {
        if (!mounted) return;
        ErrorHelper.showUnexpectedError(context, e as Exception, stackTrace,
            message: 'Unexpected error occurred while saving ignore rules.');
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
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppUsageUiConstants.onePatternPerLineHint,
                style: AppTheme.bodySmall.copyWith(
                  color: AppTheme.disabledColor,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _patternController,
                      decoration: InputDecoration(
                        labelText: AppUsageUiConstants.patternsLabel,
                        labelStyle: AppTheme.bodySmall,
                        hintText: AppUsageUiConstants.patternHint,
                        hintStyle: AppTheme.bodySmall.copyWith(fontFamily: 'monospace'),
                        prefixIcon: Icon(AppUsageUiConstants.patternIcon, size: AppUsageUiConstants.iconSize),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        alignLabelWithHint: true,
                      ),
                      style: AppTheme.bodyMedium.copyWith(fontFamily: 'monospace'),
                      validator: (value) => (value?.isEmpty ?? true) ? 'At least one pattern is required' : null,
                      maxLines: 20,
                      minLines: 1,
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
                      icon: Icon(AppUsageUiConstants.helpIcon, size: AppUsageUiConstants.iconSize),
                      tooltip: AppUsageUiConstants.patternHelpTooltip,
                      onPressed: () => RegexHelpDialog.show(context),
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Action Buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              FilledButton.icon(
                onPressed: _handleSubmit,
                style: _isSaved
                    ? FilledButton.styleFrom(
                        backgroundColor: Colors.green.shade400,
                      )
                    : null,
                icon: Icon(
                  _isSaved ? Icons.check : Icons.save,
                  size: 18,
                  color: AppTheme.darkTextColor,
                ),
                label: Text(
                  _isSaved ? 'Saved' : 'Save',
                  style: AppTheme.bodySmall.copyWith(
                    color: AppTheme.darkTextColor,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

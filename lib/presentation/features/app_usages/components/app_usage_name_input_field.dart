import 'dart:async';
import 'package:flutter/material.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/application/features/app_usages/commands/save_app_usage_command.dart';
import 'package:whph/application/features/app_usages/queries/get_app_usage_query.dart';
import 'package:whph/core/acore/errors/business_exception.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/features/app_usages/services/app_usages_service.dart';
import 'package:whph/presentation/shared/constants/app_theme.dart';
import 'package:whph/presentation/shared/utils/error_helper.dart';
import 'package:whph/presentation/features/app_usages/constants/app_usage_translation_keys.dart';
import 'package:whph/presentation/shared/services/abstraction/i_translation_service.dart';

class AppUsageNameInputField extends StatefulWidget {
  final Mediator _mediator = container.resolve<Mediator>();
  final AppUsagesService _appUsagesService = container.resolve<AppUsagesService>();

  final String id;

  AppUsageNameInputField({
    super.key,
    required this.id,
  });

  @override
  State<AppUsageNameInputField> createState() => _AppUsageNameInputFieldState();
}

class _AppUsageNameInputFieldState extends State<AppUsageNameInputField> {
  GetAppUsageQueryResponse? _appUsage;
  final TextEditingController _controller = TextEditingController();
  Timer? _debounce;
  final _translationService = container.resolve<ITranslationService>();

  @override
  void initState() {
    _getAppUsage();
    super.initState();
  }

  @override
  void dispose() {
    _controller.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _getAppUsage() async {
    try {
      var query = GetAppUsageQuery(id: widget.id);
      var response = await widget._mediator.send<GetAppUsageQuery, GetAppUsageQueryResponse>(query);
      if (mounted) {
        setState(() {
          _appUsage = response;
          _controller.text = _appUsage?.displayName ?? _appUsage?.name ?? '';
        });
      }
    } catch (e, stackTrace) {
      if (mounted) {
        ErrorHelper.showUnexpectedError(
          context,
          e as Exception,
          stackTrace,
          message: _translationService.translate(AppUsageTranslationKeys.getUsageError),
        );
      }
    }
  }

  Future<void> _saveAppUsage(BuildContext context) async {
    if (_appUsage == null) return;

    var command = SaveAppUsageCommand(
      id: widget.id,
      displayName: _appUsage!.name != _controller.text ? _controller.text : null,
      name: _appUsage!.name,
      color: _appUsage!.color,
      deviceName: _appUsage!.deviceName,
    );

    try {
      var result = await widget._mediator.send<SaveAppUsageCommand, SaveAppUsageCommandResponse>(command);

      widget._appUsagesService.onAppUsageSaved.value = result;
    } on BusinessException catch (e) {
      if (context.mounted) ErrorHelper.showError(context, e);
    } catch (e, stackTrace) {
      if (context.mounted) {
        ErrorHelper.showUnexpectedError(
          context,
          e as Exception,
          stackTrace,
          message: _translationService.translate(AppUsageTranslationKeys.saveUsageError),
        );
      }
    }
  }

  void _onChange() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();

    _debounce = Timer(const Duration(milliseconds: 500), () async {
      if (mounted) {
        setState(() {
          if (_appUsage != null) {
            _appUsage!.displayName = _controller.text;
          }
        });
      }
      await _saveAppUsage(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      onChanged: (_) => _onChange(),
      decoration: const InputDecoration(
        suffixIcon: Icon(Icons.edit, size: AppTheme.iconSizeSmall),
        border: InputBorder.none,
      ),
    );
  }
}

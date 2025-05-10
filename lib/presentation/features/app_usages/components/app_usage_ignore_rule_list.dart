import 'package:flutter/material.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/application/features/app_usages/commands/delete_app_usage_ignore_rule_command.dart';
import 'package:whph/application/features/app_usages/queries/get_list_app_usage_ignore_rules_query.dart';
import 'package:whph/domain/features/app_usages/app_usage_ignore_rule.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/features/app_usages/constants/app_usage_translation_keys.dart';
import 'package:whph/presentation/features/app_usages/constants/app_usage_ui_constants.dart';
import 'package:whph/presentation/features/app_usages/services/app_usages_service.dart';
import 'package:whph/presentation/shared/components/icon_overlay.dart';
import 'package:whph/presentation/shared/constants/app_theme.dart';
import 'package:whph/presentation/shared/constants/shared_translation_keys.dart';
import 'package:whph/presentation/shared/constants/shared_ui_constants.dart';
import 'package:whph/presentation/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/presentation/shared/utils/async_error_handler.dart';

class AppUsageIgnoreRuleList extends StatefulWidget {
  final VoidCallback? onRuleDeleted;

  const AppUsageIgnoreRuleList({
    super.key,
    this.onRuleDeleted,
  });

  @override
  State<AppUsageIgnoreRuleList> createState() => AppUsageIgnoreRuleListState();
}

class AppUsageIgnoreRuleListState extends State<AppUsageIgnoreRuleList> {
  final Mediator _mediator = container.resolve<Mediator>();
  final AppUsagesService _appUsagesService = container.resolve<AppUsagesService>();
  final ITranslationService _translationService = container.resolve<ITranslationService>();

  List<AppUsageIgnoreRule> _rules = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _setupEventListeners();
    loadItems();
  }

  @override
  void dispose() {
    _removeEventListeners();
    super.dispose();
  }

  void _setupEventListeners() {
    _appUsagesService.onAppUsageIgnoreRuleUpdated.addListener(_handleRuleChanged);
  }

  void _removeEventListeners() {
    _appUsagesService.onAppUsageIgnoreRuleUpdated.removeListener(_handleRuleChanged);
  }

  void _handleRuleChanged() {
    refresh();
  }

  Future<void> loadItems() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
    });

    await AsyncErrorHandler.execute<GetListAppUsageIgnoreRulesQueryResponse>(
      context: context,
      errorMessage: _translationService.translate(AppUsageTranslationKeys.getRulesError),
      operation: () async {
        final query = GetListAppUsageIgnoreRulesQuery(
          pageIndex: 0,
          pageSize: 50,
        );
        return await _mediator.send<GetListAppUsageIgnoreRulesQuery, GetListAppUsageIgnoreRulesQueryResponse>(query);
      },
      onSuccess: (response) {
        if (mounted) {
          setState(() {
            _rules = response.items
                .map((item) => AppUsageIgnoreRule(
                      id: item.id,
                      pattern: item.pattern,
                      description: item.description,
                      createdDate: DateTime.now(),
                    ))
                .toList();
          });
        }
      },
      finallyAction: () {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      },
    );
  }

  Future<void> refresh() async {
    await loadItems();
  }

  Future<void> deleteItem(String id) async {
    await AsyncErrorHandler.executeVoid(
      context: context,
      errorMessage: _translationService.translate(AppUsageTranslationKeys.deleteRuleError),
      operation: () async {
        final command = DeleteAppUsageIgnoreRuleCommand(id: id);
        await _mediator.send(command);
      },
      onSuccess: () async {
        _appUsagesService.notifyAppUsageIgnoreRuleUpdated(id);
        widget.onRuleDeleted?.call();
        await refresh();
      },
    );
  }

  Future<void> _confirmDelete(String id) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_translationService.translate(AppUsageTranslationKeys.deleteRuleConfirmTitle)),
        content: Text(_translationService.translate(AppUsageTranslationKeys.deleteRuleConfirmMessage)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(_translationService.translate(SharedTranslationKeys.cancelButton)),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(_translationService.translate(SharedTranslationKeys.deleteButton)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await deleteItem(id);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      // No loading indicator since local DB is fast
      return const SizedBox.shrink();
    }

    if (_rules.isEmpty) {
      return IconOverlay(
        icon: Icons.rule_folder,
        iconSize: 48,
        message: _translationService.translate(AppUsageTranslationKeys.noIgnoreRules),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _rules.length,
      separatorBuilder: (context, index) => const SizedBox(height: 4),
      itemBuilder: (context, index) {
        final rule = _rules[index];
        return Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: AppUsageUiConstants.cardPadding,
            child: Row(
              children: [
                // Pattern and Description
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Text(
                            "${_translationService.translate(AppUsageTranslationKeys.patternLabel)}:",
                            style: AppTheme.bodySmall.copyWith(color: Colors.grey),
                          ),
                          const SizedBox(width: AppTheme.sizeXSmall),
                          Expanded(
                            child: Text(
                              rule.pattern,
                              style: AppTheme.bodyMedium.copyWith(fontFamily: 'monospace', color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                      if (rule.description != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            rule.description!,
                            style: AppTheme.bodySmall,
                          ),
                        ),
                    ],
                  ),
                ),

                // Delete Button
                IconButton(
                  icon: Icon(SharedUiConstants.deleteIcon, size: AppTheme.iconSizeSmall),
                  onPressed: () => _confirmDelete(rule.id),
                  visualDensity: VisualDensity.compact,
                  tooltip: _translationService.translate(AppUsageTranslationKeys.deleteRuleTooltip),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

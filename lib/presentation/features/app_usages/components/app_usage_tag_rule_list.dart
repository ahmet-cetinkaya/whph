import 'package:flutter/material.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/application/features/app_usages/queries/get_list_app_usage_tag_rules_query.dart';
import 'package:whph/application/features/app_usages/commands/delete_app_usage_tag_rule_command.dart';
import 'package:whph/presentation/features/app_usages/services/app_usages_service.dart';
import 'package:whph/presentation/shared/constants/app_theme.dart';
import 'package:whph/presentation/shared/constants/shared_ui_constants.dart';
import 'package:whph/presentation/shared/enums/dialog_size.dart';
import 'package:whph/presentation/shared/utils/async_error_handler.dart';
import 'package:whph/presentation/shared/utils/responsive_dialog_helper.dart';
import 'package:whph/presentation/features/app_usages/constants/app_usage_ui_constants.dart';
import 'package:whph/presentation/shared/components/load_more_button.dart';
import 'package:whph/presentation/shared/constants/shared_translation_keys.dart';
import 'package:whph/presentation/features/app_usages/constants/app_usage_translation_keys.dart';
import 'package:whph/presentation/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/presentation/shared/components/icon_overlay.dart';
import 'package:whph/main.dart';

class AppUsageTagRuleList extends StatefulWidget {
  final Mediator mediator;
  final Function(String id)? onRuleSelected;
  final List<String>? filterByTags;
  final int pageSize;

  const AppUsageTagRuleList({
    super.key,
    required this.mediator,
    this.onRuleSelected,
    this.filterByTags,
    this.pageSize = 10,
  });

  @override
  State<AppUsageTagRuleList> createState() => AppUsageTagRuleListState();
}

class AppUsageTagRuleListState extends State<AppUsageTagRuleList> {
  final ScrollController _scrollController = ScrollController();
  GetListAppUsageTagRulesQueryResponse? _ruleList;
  bool _isLoading = false;
  final _translationService = container.resolve<ITranslationService>();
  final _appUsagesService = container.resolve<AppUsagesService>();
  double? _savedScrollPosition;

  @override
  void initState() {
    super.initState();
    _setupEventListeners();
    _loadRules(isRefresh: true);
  }

  @override
  void dispose() {
    _removeEventListeners();
    _scrollController.dispose();
    super.dispose();
  }

  void _setupEventListeners() {
    _appUsagesService.onAppUsageRuleCreated.addListener(_handleRuleChanged);
    _appUsagesService.onAppUsageRuleUpdated.addListener(_handleRuleChanged);
    _appUsagesService.onAppUsageRuleDeleted.addListener(_handleRuleChanged);
  }

  void _removeEventListeners() {
    _appUsagesService.onAppUsageRuleCreated.removeListener(_handleRuleChanged);
    _appUsagesService.onAppUsageRuleUpdated.removeListener(_handleRuleChanged);
    _appUsagesService.onAppUsageRuleDeleted.removeListener(_handleRuleChanged);
  }

  void _handleRuleChanged() {
    if (mounted) {
      _loadRules(isRefresh: true);
    }
  }

  void _cancelDelete() {
    Navigator.pop(context, false);
  }

  void _confirmDelete() {
    Navigator.pop(context, true);
  }

  void _saveScrollPosition() {
    if (_scrollController.hasClients && _scrollController.position.hasViewportDimension) {
      _savedScrollPosition = _scrollController.position.pixels;
    }
  }

  void _backLastScrollPosition() {
    if (_savedScrollPosition == null) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted &&
          _scrollController.hasClients &&
          _scrollController.position.hasViewportDimension &&
          _savedScrollPosition! <= _scrollController.position.maxScrollExtent) {
        _scrollController.jumpTo(_savedScrollPosition!);
      }
    });
  }

  Future<void> refresh() async {
    _saveScrollPosition();
    await _loadRules(isRefresh: true);
    _backLastScrollPosition();
  }

  Future<void> _loadRules({int pageIndex = 0, bool isRefresh = false}) async {
    if (_isLoading) return;

    setState(() => _isLoading = true);

    await AsyncErrorHandler.execute<GetListAppUsageTagRulesQueryResponse>(
      context: context,
      errorMessage: _translationService.translate(AppUsageTranslationKeys.getRulesError),
      operation: () async {
        final query = GetListAppUsageTagRulesQuery(
          pageIndex: pageIndex,
          pageSize: isRefresh && (_ruleList?.items.length ?? 0) > widget.pageSize
              ? _ruleList?.items.length ?? widget.pageSize
              : widget.pageSize,
          filterByTags: widget.filterByTags,
        );

        return await widget.mediator.send<GetListAppUsageTagRulesQuery, GetListAppUsageTagRulesQueryResponse>(query);
      },
      onSuccess: (result) {
        if (mounted) {
          setState(() {
            if (_ruleList == null || pageIndex == 0) {
              _ruleList = result;
            } else {
              _ruleList!.items.addAll(result.items);
              _ruleList!.pageIndex = result.pageIndex;
            }
          });
        }
      },
    );

    // Set loading state to false after completion
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading && _ruleList == null) {
      // No loading indicator since local DB is fast
      return const SizedBox.shrink();
    }

    if (_ruleList == null || _ruleList!.items.isEmpty) {
      return IconOverlay(
        icon: Icons.rule_folder,
        iconSize: AppTheme.iconSizeXLarge,
        message: _translationService.translate(AppUsageTranslationKeys.noRules),
      );
    }

    return SingleChildScrollView(
      controller: _scrollController,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _ruleList!.items.length,
            separatorBuilder: (context, index) => const SizedBox(height: 4),
            itemBuilder: (context, index) {
              final rule = _ruleList!.items[index];
              return Card(
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: AppUsageUiConstants.cardPadding,
                  child: Row(
                    children: [
                      // Tag
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.surface1,
                          borderRadius: BorderRadius.circular(AppUsageUiConstants.tagContainerBorderRadius),
                        ),
                        child: Text(
                          rule.tagName,
                          style: AppTheme.bodySmall.copyWith(
                            color: AppUsageUiConstants.getTagColor(rule.tagColor),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),

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
                                const SizedBox(width: AppTheme.size2XSmall),
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
                        onPressed: () {
                          if (mounted) _delete(context, rule);
                        },
                        visualDensity: VisualDensity.compact,
                        tooltip: _translationService.translate(AppUsageTranslationKeys.deleteRuleTooltip),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          if (_ruleList!.hasNext)
            Padding(
              padding: const EdgeInsets.only(top: AppTheme.size2XSmall),
              child: Center(child: LoadMoreButton(onPressed: _onLoadMore)),
            ),
        ],
      ),
    );
  }

  Future<void> _onLoadMore() async {
    if (_ruleList == null || !_ruleList!.hasNext) return;

    _saveScrollPosition();
    await _loadRules(pageIndex: _ruleList!.pageIndex + 1);
    _backLastScrollPosition();
  }

  Future<void> _delete(BuildContext context, AppUsageTagRuleListItem rule) async {
    if (!mounted) return;

    final confirmed = await ResponsiveDialogHelper.showResponsiveDialog<bool>(
      context: context,
      size: DialogSize.min,
      child: AlertDialog(
        title: Text(_translationService.translate(AppUsageTranslationKeys.deleteRuleTitle)),
        content: Text(_translationService
            .translate(AppUsageTranslationKeys.deleteRuleConfirm, namedArgs: {'pattern': rule.pattern})),
        actions: [
          TextButton(
            onPressed: _cancelDelete,
            child: Text(_translationService.translate(SharedTranslationKeys.cancelButton)),
          ),
          TextButton(
            onPressed: _confirmDelete,
            child: Text(_translationService.translate(SharedTranslationKeys.deleteButton)),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      await AsyncErrorHandler.executeVoid(
        context: context,
        errorMessage: _translationService.translate(AppUsageTranslationKeys.deleteRuleError),
        operation: () async {
          final command = DeleteAppUsageTagRuleCommand(id: rule.id);
          await widget.mediator.send<DeleteAppUsageTagRuleCommand, DeleteAppUsageTagRuleCommandResponse>(command);
        },
        onSuccess: () {
          // Notify listeners about the rule deletion
          _appUsagesService.notifyAppUsageRuleDeleted(rule.id);
          // The component will refresh automatically through event listener
        },
      );
    }
  }
}

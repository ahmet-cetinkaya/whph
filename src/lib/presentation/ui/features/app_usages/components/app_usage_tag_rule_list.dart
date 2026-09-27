import 'dart:math';

import 'package:flutter/material.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/core/application/features/app_usages/queries/get_list_app_usage_tag_rules_query.dart';
import 'package:whph/core/application/features/app_usages/commands/delete_app_usage_tag_rule_command.dart';
import 'package:whph/presentation/ui/features/app_usages/services/app_usages_service.dart';
import 'package:whph/presentation/ui/shared/constants/app_theme.dart';
import 'package:whph/presentation/ui/shared/constants/shared_ui_constants.dart';
import 'package:acore/utils/dialog_size.dart';
import 'package:whph/presentation/ui/shared/utils/async_error_handler.dart';
import 'package:whph/presentation/ui/shared/utils/pagination_utils.dart';
import 'package:acore/utils/responsive_dialog_helper.dart';
import 'package:whph/presentation/ui/features/app_usages/constants/app_usage_ui_constants.dart';
import 'package:whph/presentation/ui/shared/components/load_more_button.dart';
import 'package:whph/presentation/ui/shared/constants/shared_translation_keys.dart';
import 'package:whph/presentation/ui/features/app_usages/constants/app_usage_translation_keys.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/presentation/ui/shared/components/icon_overlay.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/ui/shared/enums/pagination_mode.dart';
import 'package:whph/presentation/ui/shared/mixins/pagination_mixin.dart';

class AppUsageTagRuleList extends StatefulWidget implements IPaginatedWidget {
  final Mediator mediator;
  final Function(String id)? onRuleSelected;
  final List<String>? filterByTags;
  final int pageSize;
  @override
  final PaginationMode paginationMode;

  const AppUsageTagRuleList({
    super.key,
    required this.mediator,
    this.onRuleSelected,
    this.filterByTags,
    this.pageSize = 10,
    this.paginationMode = PaginationMode.loadMore,
  });

  @override
  State<AppUsageTagRuleList> createState() => AppUsageTagRuleListState();
}

class AppUsageTagRuleListState extends State<AppUsageTagRuleList> with PaginationMixin<AppUsageTagRuleList> {
  final ScrollController _scrollController = ScrollController();
  GetListAppUsageTagRulesQueryResponse? _ruleList;
  bool _isLoading = false;
  final _translationService = container.resolve<ITranslationService>();
  final _appUsagesService = container.resolve<AppUsagesService>();
  int _cursor = 0;
  int _loadGeneration = 0;

  bool get _hasMore =>
      _ruleList != null && PaginationUtils.hasMore(cursor: _cursor, totalItemCount: _ruleList!.totalItemCount);

  @override
  ScrollController get scrollController => _scrollController;

  @override
  bool get hasNextPage => _hasMore;

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

  Future<void> refresh() async {
    await _loadRules(isRefresh: true, keepScroll: true);
  }

  Future<void> _loadRules({int pageIndex = 0, bool isRefresh = false, bool keepScroll = false}) async {
    // Only load-more is blocked by an in-flight load; refreshes always run and win via the load generation.
    if (_isLoading && !isRefresh) return;

    final int requestPageIndex = isRefresh ? 0 : pageIndex;
    final int requestPageSize = isRefresh ? max(_cursor, widget.pageSize) : widget.pageSize;
    if (isRefresh || _ruleList == null) _loadGeneration++;
    final gen = _loadGeneration;

    setState(() => _isLoading = true);

    await AsyncErrorHandler.execute<GetListAppUsageTagRulesQueryResponse>(
      context: context,
      errorMessage: _translationService.translate(AppUsageTranslationKeys.getRulesError),
      operation: () async {
        final query = GetListAppUsageTagRulesQuery(
          pageIndex: requestPageIndex,
          pageSize: requestPageSize,
          filterByTags: widget.filterByTags,
        );

        return await widget.mediator.send<GetListAppUsageTagRulesQuery, GetListAppUsageTagRulesQueryResponse>(query);
      },
      onSuccess: (result) {
        if (gen != _loadGeneration || !mounted) return;

        final offset = keepScroll ? captureScrollOffset() : null;
        setState(() {
          _cursor = PaginationUtils.cursorAfter(
            pageIndex: requestPageIndex,
            pageSize: requestPageSize,
            totalItemCount: result.totalItemCount,
          );
          if (isRefresh || _ruleList == null) {
            _ruleList = result;
          } else {
            _ruleList!.items = PaginationUtils.appendUnique(_ruleList!.items, result.items, (r) => r.id);
            _ruleList!.pageIndex = result.pageIndex;
            _ruleList!.totalItemCount = result.totalItemCount;
          }
        });
        if (keepScroll) restoreScrollOffset(offset);

        // For infinity scroll: check if viewport needs more content
        if (widget.paginationMode == PaginationMode.infinityScroll && _hasMore) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            checkAndFillViewport();
          });
        }
      },
    );

    // Only the newest-generation load clears the loading state; a superseded load must not clear it while the
    // newer load that owns it is still in flight.
    if (mounted && gen == _loadGeneration) {
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
      return Padding(
        padding: const EdgeInsets.all(AppTheme.sizeMedium),
        child: IconOverlay(
          icon: Icons.rule_folder,
          iconSize: AppTheme.iconSizeXLarge,
          message: _translationService.translate(AppUsageTranslationKeys.noRules),
        ),
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
                          rule.tagName.isNotEmpty
                              ? rule.tagName
                              : _translationService.translate(SharedTranslationKeys.untitled),
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
                                    style: AppTheme.bodyMedium.copyWith(fontFamily: 'monospace'),
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
          if (_hasMore && widget.paginationMode == PaginationMode.loadMore)
            Padding(
              padding: const EdgeInsets.only(top: AppTheme.size2XSmall),
              child: Center(child: LoadMoreButton(onPressed: onLoadMore)),
            ),
          if (_hasMore && widget.paginationMode == PaginationMode.infinityScroll && isLoadingMore)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: AppTheme.sizeMedium),
              child: Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }

  @override
  Future<void> onLoadMore() async {
    if (!_hasMore) return;
    await _loadRules(pageIndex: PaginationUtils.nextPageIndex(cursor: _cursor, pageSize: widget.pageSize));
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

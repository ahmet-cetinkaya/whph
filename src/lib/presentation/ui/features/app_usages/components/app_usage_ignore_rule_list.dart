import 'package:flutter/material.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/core/application/features/app_usages/commands/delete_app_usage_ignore_rule_command.dart';
import 'package:whph/core/application/features/app_usages/queries/get_list_app_usage_ignore_rules_query.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/ui/features/app_usages/constants/app_usage_translation_keys.dart';
import 'package:whph/presentation/ui/features/app_usages/constants/app_usage_ui_constants.dart';
import 'package:whph/presentation/ui/features/app_usages/services/app_usages_service.dart';
import 'package:whph/presentation/ui/shared/components/icon_overlay.dart';
import 'package:whph/presentation/ui/shared/components/load_more_button.dart';
import 'package:whph/presentation/ui/shared/constants/app_theme.dart';
import 'package:whph/presentation/ui/shared/constants/shared_translation_keys.dart';
import 'package:whph/presentation/ui/shared/constants/shared_ui_constants.dart';
import 'package:acore/utils/dialog_size.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/presentation/ui/shared/utils/async_error_handler.dart';
import 'package:acore/utils/responsive_dialog_helper.dart';
import 'package:whph/presentation/ui/shared/enums/pagination_mode.dart';

class AppUsageIgnoreRuleList extends StatefulWidget {
  final VoidCallback? onRuleDeleted;
  final int pageSize;
  final PaginationMode paginationMode;

  const AppUsageIgnoreRuleList({
    super.key,
    this.onRuleDeleted,
    this.pageSize = 10,
    this.paginationMode = PaginationMode.loadMore,
  });

  @override
  State<AppUsageIgnoreRuleList> createState() => AppUsageIgnoreRuleListState();
}

class AppUsageIgnoreRuleListState extends State<AppUsageIgnoreRuleList> {
  final Mediator _mediator = container.resolve<Mediator>();
  final AppUsagesService _appUsagesService = container.resolve<AppUsagesService>();
  final ITranslationService _translationService = container.resolve<ITranslationService>();
  final ScrollController _scrollController = ScrollController();

  GetListAppUsageIgnoreRulesQueryResponse? _ruleList;
  bool _isLoading = false;
  double _savedScrollPosition = 0.0;
  bool _isLoadingMore = false;

  @override
  void initState() {
    super.initState();
    _setupEventListeners();
    _getList();
    _setupScrollListener();
  }

  @override
  void dispose() {
    _removeEventListeners();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _setupScrollListener() {
    if (widget.paginationMode == PaginationMode.infinityScroll) {
      _scrollController.addListener(_onScroll);
    }
  }

  void _onScroll() {
    if (widget.paginationMode != PaginationMode.infinityScroll) return;
    if (_isLoadingMore || _ruleList == null || !_ruleList!.hasNext) return;

    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.position.pixels;
    final threshold = maxScroll * 0.8;

    if (currentScroll >= threshold) {
      _loadMoreInfinityScroll();
    }
  }

  Future<void> _loadMoreInfinityScroll() async {
    if (_isLoadingMore || _ruleList == null || !_ruleList!.hasNext) return;

    setState(() => _isLoadingMore = true);
    await _getList(pageIndex: _ruleList!.pageIndex + 1);
    if (mounted) {
      setState(() => _isLoadingMore = false);
    }
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

  void _saveScrollPosition() {
    if (_scrollController.hasClients) {
      _savedScrollPosition = _scrollController.offset;
    }
  }

  void _backLastScrollPosition() {
    if (_scrollController.hasClients && _savedScrollPosition > 0.0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _savedScrollPosition,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  Future<void> _getList({int pageIndex = 0, bool isRefresh = false}) async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
    });

    await AsyncErrorHandler.execute<GetListAppUsageIgnoreRulesQueryResponse>(
      context: context,
      errorMessage: _translationService.translate(AppUsageTranslationKeys.getRulesError),
      operation: () async {
        final query = GetListAppUsageIgnoreRulesQuery(
          pageIndex: pageIndex,
          pageSize: isRefresh && (_ruleList?.items.length ?? 0) > widget.pageSize
              ? _ruleList?.items.length ?? widget.pageSize
              : widget.pageSize,
        );
        return await _mediator.send<GetListAppUsageIgnoreRulesQuery, GetListAppUsageIgnoreRulesQueryResponse>(query);
      },
      onSuccess: (response) {
        if (mounted) {
          setState(() {
            if (_ruleList == null || pageIndex == 0 || isRefresh) {
              _ruleList = response;
            } else {
              // Append new items for load more
              _ruleList!.items.addAll(response.items);
              _ruleList!.pageIndex = response.pageIndex;
            }
          });

          // For infinity scroll: check if viewport needs more content
          if (widget.paginationMode == PaginationMode.infinityScroll && (_ruleList?.hasNext ?? false)) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _checkAndFillViewport();
            });
          }
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
    _saveScrollPosition();
    await _getList(isRefresh: true);
    _backLastScrollPosition();
  }

  void _checkAndFillViewport() {
    if (!mounted || _isLoadingMore || _ruleList == null || !_ruleList!.hasNext) return;
    if (!_scrollController.hasClients) return;

    final maxScroll = _scrollController.position.maxScrollExtent;
    if (maxScroll <= 0) {
      _loadMoreInfinityScroll();
    }
  }

  Future<void> _onLoadMore() async {
    if (_ruleList?.hasNext == false) return;

    _saveScrollPosition();
    await _getList(pageIndex: _ruleList!.pageIndex + 1);
    _backLastScrollPosition();
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

  void _cancelDelete() {
    Navigator.of(context).pop(false);
  }

  void _confirmDeleteAction() {
    Navigator.of(context).pop(true);
  }

  Future<void> _confirmDelete(String id) async {
    final bool? confirmed = await ResponsiveDialogHelper.showResponsiveDialog<bool>(
      context: context,
      size: DialogSize.min,
      child: AlertDialog(
        title: Text(_translationService.translate(AppUsageTranslationKeys.deleteRuleConfirmTitle)),
        content: Text(_translationService.translate(AppUsageTranslationKeys.deleteRuleConfirmMessage)),
        actions: [
          TextButton(
            onPressed: _cancelDelete,
            child: Text(_translationService.translate(SharedTranslationKeys.cancelButton)),
          ),
          TextButton(
            onPressed: _confirmDeleteAction,
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
    if (_isLoading && _ruleList == null) {
      // No loading indicator since local DB is fast
      return const SizedBox.shrink();
    }

    if (_ruleList?.items.isEmpty ?? true) {
      return Padding(
        padding: const EdgeInsets.all(AppTheme.sizeMedium),
        child: IconOverlay(
          icon: Icons.rule_folder,
          iconSize: AppTheme.iconSizeXLarge,
          message: _translationService.translate(AppUsageTranslationKeys.noIgnoreRules),
        ),
      );
    }

    return Column(
      children: [
        ListView.separated(
          controller: _scrollController,
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
                      onPressed: () => _confirmDelete(rule.id),
                      visualDensity: VisualDensity.compact,
                      tooltip: _translationService.translate(AppUsageTranslationKeys.deleteRuleTooltip),
                    ),
                  ],
                ),
              ),
            );
          },
        ),

        // Load more button
        if (_ruleList!.hasNext && widget.paginationMode == PaginationMode.loadMore)
          Padding(
            padding: const EdgeInsets.only(top: AppTheme.size2XSmall),
            child: Center(
              child: LoadMoreButton(
                onPressed: _onLoadMore,
              ),
            ),
          ),
        if (_ruleList!.hasNext && widget.paginationMode == PaginationMode.infinityScroll && _isLoadingMore)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: AppTheme.sizeMedium),
            child: Center(child: CircularProgressIndicator()),
          ),
      ],
    );
  }
}

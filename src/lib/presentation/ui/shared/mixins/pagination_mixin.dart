import 'dart:async';
import 'package:flutter/material.dart';
import 'package:whph/presentation/ui/shared/enums/pagination_mode.dart';

abstract class IPaginatedWidget {
  PaginationMode get paginationMode;
}

mixin PaginationMixin<T extends StatefulWidget> on State<T> {
  ScrollController get scrollController;
  Future<void> onLoadMore();
  bool get hasNextPage;

  bool _isLoadingMore = false;
  bool get isLoadingMore => _isLoadingMore;

  static const double _infinityScrollThresholdRatio = 0.8;
  static const double _viewportFillThreshold = 10.0;

  @override
  void initState() {
    super.initState();
    _setupScrollListener();
  }

  @override
  void didUpdateWidget(T oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget is IPaginatedWidget && oldWidget is IPaginatedWidget) {
      final newMode = (widget as IPaginatedWidget).paginationMode;
      final oldMode = (oldWidget as IPaginatedWidget).paginationMode;
      if (newMode != oldMode) {
        _updateScrollListener(oldMode, newMode);
      }
    }
  }

  @override
  void dispose() {
    _removeScrollListener();
    super.dispose();
  }

  void _setupScrollListener() {
    if (widget is IPaginatedWidget && (widget as IPaginatedWidget).paginationMode == PaginationMode.infinityScroll) {
      scrollController.addListener(_onScroll);
    }
  }

  void _removeScrollListener() {
    try {
      scrollController.removeListener(_onScroll);
    } catch (_) {
      // Ignore if controller already disposed or not attached
    }
  }

  void _updateScrollListener(PaginationMode oldMode, PaginationMode newMode) {
    if (oldMode == PaginationMode.infinityScroll) {
      _removeScrollListener();
    }
    if (newMode == PaginationMode.infinityScroll) {
      scrollController.addListener(_onScroll);
    }
  }

  void _onScroll() {
    if (!_shouldLoadMore()) return;

    if (!scrollController.hasClients) return;

    try {
      final maxScroll = scrollController.position.maxScrollExtent;
      final currentScroll = scrollController.position.pixels;
      final threshold = maxScroll * _infinityScrollThresholdRatio;

      if (currentScroll >= threshold) {
        loadMoreInfinityScroll();
      }
    } catch (e) {
      // Handle any potential errors accessing position
      debugPrint('Error accessing scroll position: $e');
    }
  }

  bool _shouldLoadMore() {
    if (widget is IPaginatedWidget && (widget as IPaginatedWidget).paginationMode != PaginationMode.infinityScroll) {
      return false;
    }
    if (_isLoadingMore || !hasNextPage) return false;
    return true;
  }

  Future<void> loadMoreInfinityScroll() async {
    if (_isLoadingMore || !hasNextPage) return;

    if (_loadCompleter != null) {
      await _loadCompleter!.future;
      return;
    }

    _loadCompleter = Completer<void>();
    setState(() => _isLoadingMore = true);

    try {
      await onLoadMore();
      _loadCompleter!.complete();
    } catch (e) {
      debugPrint('Error in infinity scroll load: $e');
      _loadCompleter!.completeError(e);
    } finally {
      _loadCompleter = null;
      if (mounted) {
        setState(() => _isLoadingMore = false);
      }
    }
  }

  Completer<void>? _loadCompleter;

  void checkAndFillViewport() {
    if (!mounted || _isLoadingMore || !hasNextPage) return;
    if (!scrollController.hasClients) return;

    if (_isCheckingViewport) return;
    _isCheckingViewport = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _isCheckingViewport = false;
    });

    try {
      final maxScrollExtent = scrollController.position.maxScrollExtent;

      if (maxScrollExtent <= _viewportFillThreshold) {
        Future.microtask(() {
          if (mounted && !_isLoadingMore && hasNextPage) {
            loadMoreInfinityScroll();
          }
        });
      }
    } catch (e) {
      // Handle any potential errors accessing position
      debugPrint('Error accessing scroll position in checkAndFillViewport: $e');
    }
  }

  bool _isCheckingViewport = false;
}

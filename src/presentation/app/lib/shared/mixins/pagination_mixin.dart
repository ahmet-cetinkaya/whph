import 'dart:async';
import 'package:flutter/material.dart';
import 'package:whph/shared/enums/pagination_mode.dart';

/// Interface for widgets that support pagination mode
abstract class IPaginatedWidget {
  PaginationMode get paginationMode;
}

/// Mixin to handle infinity scroll pagination logic
mixin PaginationMixin<T extends StatefulWidget> on State<T> {
  // Required dependencies to be implemented by the host state
  ScrollController get scrollController;
  Future<void> onLoadMore();
  bool get hasNextPage;

  // Internal state
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

    // In Flutter 3.32.0+, position is non-nullable when hasClients is true
    // but we wrap it in try-catch for additional safety
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
    // Prevent race condition: do not load if already loading
    if (_isLoadingMore || !hasNextPage) return false;
    return true;
  }

  Future<void> loadMoreInfinityScroll() async {
    // Synchronized access to prevent race condition
    if (_isLoadingMore || !hasNextPage) return;

    // Use a completer to ensure only one operation at a time
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
      // Robust error handling: Log error or allow retry
      debugPrint('Error in infinity scroll load: $e');
      _loadCompleter!.completeError(e);
    } finally {
      _loadCompleter = null;
      if (mounted) {
        setState(() => _isLoadingMore = false);
      }
    }
  }

  // Completer for synchronization
  Completer<void>? _loadCompleter;

  /// Checks if viewport is full and loads more if needed.
  /// Should be called after data load.
  void checkAndFillViewport() {
    if (!mounted || _isLoadingMore || !hasNextPage) return;
    if (!scrollController.hasClients) return;

    // Prevent duplicate calls during the same frame cycle
    if (_isCheckingViewport) return;
    _isCheckingViewport = true;

    // Schedule the check for the next frame to avoid race conditions
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _isCheckingViewport = false;
    });

    // In Flutter 3.32.0+, position is non-nullable when hasClients is true
    // but we wrap it in try-catch for additional safety
    try {
      final maxScrollExtent = scrollController.position.maxScrollExtent;

      // Use extentAfter/maxScrollExtent to determine if content fills the viewport.
      // If maxScrollExtent is very small, it means the content fits in the viewport
      // and we might need to load more to trigger the scroll capability.
      // The threshold is a small epsilon to account for potential minor layout variations.
      if (maxScrollExtent <= _viewportFillThreshold) {
        // Use Future.microtask to defer the call and avoid immediate recursion
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

  // Flag to prevent duplicate viewport checks
  bool _isCheckingViewport = false;
}

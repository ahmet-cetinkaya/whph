import 'package:acore/acore.dart';

/// The outcome of resolving where a moved item should land and what its new
/// order value is, given the authoritative order-sorted sibling set.
class ReorderPlacement<T> {
  /// The 0-based insertion index within the sibling set (which excludes the
  /// moved item), clamped to `[0, siblings.length]`.
  final int position;

  /// When `false`, [order] is a gap-safe value to assign to the moved item and
  /// only that item needs persisting.
  ///
  /// When `true`, the whole sibling set could no longer accept a reliable
  /// midpoint insertion (duplicate/collapsed/overflowing orders); the caller
  /// must renumber every sibling. Use [renumbered] for the fully-ordered list
  /// with clean [OrderRank.initialStep] multiples already assigned.
  final bool requiresRenormalization;

  /// The order to assign to the moved item (valid in both branches).
  final double order;

  /// Present only when [requiresRenormalization] is `true`: the full sibling
  /// set (including the moved item) in final order with clean orders already
  /// assigned to each element via the caller-supplied `setOrder`.
  final List<T>? renumbered;

  const ReorderPlacement({
    required this.position,
    required this.requiresRenormalization,
    required this.order,
    this.renumbered,
  });
}

/// Single source of truth for the "resolve position → compute gap-safe rank →
/// renormalize on collision" algorithm shared by every custom-ordered feature
/// (tasks, habits, ...).
///
/// Feature command handlers stay thin: they fetch the entity and its
/// order-sorted siblings via their own repository, delegate to
/// [computePlacement], then persist either the single moved entity or the whole
/// renumbered set in one transactional batch.
class SiblingReorderService {
  const SiblingReorderService();

  /// Computes where [movedId] should land among [siblings] (which must exclude
  /// the moved item and be sorted ascending by order) and what order value(s)
  /// to persist.
  ///
  /// Position is resolved with the following precedence (a stale hint that no
  /// longer resolves is skipped, so the command degrades gracefully when a
  /// neighbor was concurrently deleted):
  ///   1. [afterId] — insert immediately *before* that sibling.
  ///   2. [beforeId] — insert immediately *after* that sibling.
  ///   3. [targetIndex] — clamped to `[0, siblings.length]`.
  ReorderPlacement<T> computePlacement<T>({
    required T moved,
    required List<T> siblings,
    required int targetIndex,
    String? beforeId,
    String? afterId,
    required String Function(T item) idOf,
    required double Function(T item) orderOf,
    required void Function(T item, double order) setOrder,
  }) {
    final position = _resolvePosition(
      siblings: siblings,
      targetIndex: targetIndex,
      beforeId: beforeId,
      afterId: afterId,
      idOf: idOf,
    );

    final currentOrders = siblings.map(orderOf).toList();
    final beforeOrder = position > 0 ? orderOf(siblings[position - 1]) : null;
    final afterOrder = position < siblings.length ? orderOf(siblings[position]) : null;

    if (OrderRank.needsNormalization(currentOrders) ||
        OrderRank.cannotFit(beforeOrder: beforeOrder, afterOrder: afterOrder)) {
      final ordered = List<T>.from(siblings);
      final clampedPosition = position.clamp(0, ordered.length);
      ordered.insert(clampedPosition, moved);
      final placedOrder = OrderRank.assignSequential<T>(
        ordered,
        setOrder: setOrder,
        isPlaced: (item) => idOf(item) == idOf(moved),
      );
      return ReorderPlacement<T>(
        position: clampedPosition,
        requiresRenormalization: true,
        order: placedOrder,
        renumbered: ordered,
      );
    }

    final newOrder = OrderRank.neighborRank(beforeOrder: beforeOrder, afterOrder: afterOrder);
    setOrder(moved, newOrder);
    return ReorderPlacement<T>(
      position: position,
      requiresRenormalization: false,
      order: newOrder,
    );
  }

  int _resolvePosition<T>({
    required List<T> siblings,
    required int targetIndex,
    String? beforeId,
    String? afterId,
    required String Function(T item) idOf,
  }) {
    if (afterId != null) {
      final idx = siblings.indexWhere((s) => idOf(s) == afterId);
      if (idx != -1) return idx; // Insert *before* the "after" neighbor.
    }
    if (beforeId != null) {
      final idx = siblings.indexWhere((s) => idOf(s) == beforeId);
      if (idx != -1) return idx + 1; // Insert *after* the "before" neighbor.
    }
    return targetIndex.clamp(0, siblings.length);
  }
}

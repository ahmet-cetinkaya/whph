import 'package:acore/acore.dart';

/// The outcome of resolving where a moved item should land and what its new
/// order value(s) should be, given the authoritative order-sorted sibling
/// set. Pure data: computing a placement never mutates [moved] or any
/// sibling — the caller applies the returned rank(s) to its own entities
/// right before persisting them, which is also the only place those
/// entities are ever written to.
class ReorderPlacement<T> {
  /// The 0-based insertion index within the sibling set (which excludes the
  /// moved item), clamped to `[0, siblings.length]`.
  final int position;

  /// When `false`, [order] is a gap-safe value for the moved item and only
  /// that item needs persisting (with its order set to [order]).
  ///
  /// When `true`, the whole sibling set could no longer accept a reliable
  /// midpoint insertion (duplicate/collapsed/overflowing orders); the caller
  /// must renumber every sibling. [renumbered] holds each affected entity —
  /// including the moved one — in final order; [renumberedOrder] holds the
  /// rank to assign each one, keyed by id.
  final bool requiresRenormalization;

  /// The order for the moved item (valid in both branches).
  final String order;

  /// Present only when [requiresRenormalization] is `true`: every entity that
  /// needs its order persisted, including the moved one, in final order.
  final List<T>? renumbered;

  /// Present only when [requiresRenormalization] is `true`: id → new rank for
  /// every entity in [renumbered]. The caller assigns
  /// `entity.order = renumberedOrder[idOf(entity)]!` before persisting.
  final Map<String, String>? renumberedOrder;

  const ReorderPlacement({
    required this.position,
    required this.requiresRenormalization,
    required this.order,
    this.renumbered,
    this.renumberedOrder,
  });
}

/// Single source of truth for the "resolve position → compute gap-safe rank →
/// renormalize on collision" algorithm shared by every custom-ordered feature
/// (tasks, habits, ...).
///
/// Feature command handlers stay thin: they fetch the entity and its
/// order-sorted siblings via their own repository, delegate to
/// [computePlacement], apply the returned rank(s) to their own entities, then
/// persist either the single moved entity or the whole renumbered set in one
/// transactional batch.
class SiblingReorderService {
  const SiblingReorderService();

  /// Computes where [moved] should land among [siblings] (which must exclude
  /// the moved item and be sorted ascending by order) and what order
  /// value(s) to persist. Never mutates [moved] or any sibling.
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
    required String Function(T item) orderOf,
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
        OrderRank.cannotFit(beforeOrder: beforeOrder, afterOrder: afterOrder))
      return _renormalizedPlacement(
        moved: moved,
        siblings: siblings,
        position: position,
        idOf: idOf,
      );

    try {
      final newOrder = OrderRank.neighborRank(beforeOrder: beforeOrder, afterOrder: afterOrder);
      return ReorderPlacement<T>(
        position: position,
        requiresRenormalization: false,
        order: newOrder,
      );
    } on RankGapTooSmallException {
      return _renormalizedPlacement(
        moved: moved,
        siblings: siblings,
        position: position,
        idOf: idOf,
      );
    }
  }

  ReorderPlacement<T> _renormalizedPlacement<T>({
    required T moved,
    required List<T> siblings,
    required int position,
    required String Function(T item) idOf,
  }) {
    final clampedPosition = position.clamp(0, siblings.length);
    final ordered = List<T>.from(siblings)..insert(clampedPosition, moved);
    final movedId = idOf(moved);

    final renumberedOrder = <String, String>{};
    OrderRank.assignSequential<T>(
      ordered,
      setOrder: (item, order) => renumberedOrder[idOf(item)] = order,
      isPlaced: (item) => idOf(item) == movedId,
    );

    return ReorderPlacement<T>(
      position: clampedPosition,
      requiresRenormalization: true,
      order: renumberedOrder[movedId]!,
      renumbered: ordered,
      renumberedOrder: renumberedOrder,
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

class OrderRank {
  static const double minOrder = 0;
  static const double maxOrder = 1000000;
  static const double initialStep = 1000;
  static const double minimumOrderGap = 1;

  // Calculate midpoint between two orders
  static double between(double beforeOrder, double afterOrder) {
    if (beforeOrder >= afterOrder || (afterOrder - beforeOrder) < minimumOrderGap) {
      throw RankGapTooSmallException();
    }
    final result = beforeOrder + ((afterOrder - beforeOrder) / 2);
    return result;
  }

  // Get order value for first position
  static double first() {
    return initialStep;
  }

  // Get next available order after the given one
  static double after(double currentOrder) {
    if (currentOrder >= maxOrder - initialStep) {
      throw RankGapTooSmallException();
    }
    final result = currentOrder + initialStep;
    return result;
  }

  // Get next available order before the given one
  static double before(double currentOrder) {
    if (currentOrder <= initialStep) {
      return currentOrder / 2;
    }
    final result = currentOrder - initialStep;
    return result;
  }

  // Find target order for moving an item to a specific position
  static double getTargetOrder(List<double> existingOrders, int targetPosition) {
    if (existingOrders.isEmpty) {
      return initialStep;
    }

    // Sort to ensure we're working with ordered data
    existingOrders.sort();

    // Handle special cases
    if (targetPosition <= 0) {
      // Place at beginning - use half of first item's order to ensure it comes first
      final firstOrder = existingOrders.first;
      if (firstOrder > initialStep) {
        final result = firstOrder / 2;
        return result;
      } else if (firstOrder > 1e-6) {
        // If first order is small but not too small, make it 1000 times smaller
        final result = firstOrder / 1000;
        return result;
      } else if (firstOrder > 1e-10) {
        // If first order is very small, make it even smaller
        final result = firstOrder / 1000;
        return result;
      } else {
        // If first order is extremely small or zero, use a tiny safe value
        final result = 1e-12;
        return result;
      }
    }

    if (targetPosition >= existingOrders.length) {
      // Place at end - add a significant step to the last order to ensure it comes last
      final result = existingOrders.last + initialStep * 2;
      return result;
    }

    // Get orders before and after target position
    final beforeOrder = existingOrders[targetPosition - 1];
    final afterOrder = existingOrders[targetPosition];
    try {
      // Try to place in between
      final result = between(beforeOrder, afterOrder);
      return result;
    } catch (e) {
      // If the gap is too small, create a larger gap
      if (targetPosition < existingOrders.length - 1) {
        // Not at the end, place closer to the next item
        final result = afterOrder - (minimumOrderGap / 2);
        return result;
      } else {
        // At the end, place after the last item
        final result = beforeOrder + initialStep;
        return result;
      }
    }
  }

  // Normalize all orders when gaps get too small
  static List<double> normalize(List<double> currentOrders) {
    if (currentOrders.isEmpty) return [];

    List<double> newOrders = [];
    double step = initialStep;

    for (int i = 0; i < currentOrders.length; i++) {
      newOrders.add(step);
      step += initialStep;
    }

    return newOrders;
  }
}

class RankGapTooSmallException implements Exception {
  final String message = 'Reordering needed - gaps between items too small';
}

class OrderRank {
  static const double minOrder = 0;
  static const double maxOrder = 1000000; // Upper limit for normalization
  static const double initialStep = 1000;
  static const double minimumOrderGap = 1;

  // Calculate midpoint between two orders
  static double between(double beforeOrder, double afterOrder) {
    if (beforeOrder >= afterOrder || (afterOrder - beforeOrder) < minimumOrderGap) {
      throw RankGapTooSmallException();
    }
    return beforeOrder + ((afterOrder - beforeOrder) / 2);
  }

  // Get order value for first position
  static double first() => initialStep;

  // Get next available order after the given one
  static double after(double currentOrder) {
    if (currentOrder >= maxOrder - initialStep) {
      throw RankGapTooSmallException();
    }
    return currentOrder + initialStep;
  }

  // Get next available order before the given one
  static double before(double currentOrder) {
    if (currentOrder <= initialStep) {
      return currentOrder / 2;
    }
    return currentOrder - initialStep;
  }

  // Find target order for moving an item to a specific position
  static double getTargetOrder(List<double> existingOrders, int targetPosition) {
    if (existingOrders.isEmpty) return initialStep;

    // Sort to ensure we're working with ordered data
    existingOrders.sort();

    // Handle special cases
    if (targetPosition <= 0) {
      // Place at beginning - use half of first item's order to ensure it comes first
      return existingOrders.first > initialStep ? existingOrders.first / 2 : initialStep / 2;
    }

    if (targetPosition >= existingOrders.length) {
      // Place at end - add a significant step to the last order to ensure it comes last
      return existingOrders.last + initialStep * 2;
    }

    // Get orders before and after target position
    final beforeOrder = existingOrders[targetPosition - 1];
    final afterOrder = existingOrders[targetPosition];

    try {
      // Try to place in between
      return between(beforeOrder, afterOrder);
    } catch (e) {
      // If the gap is too small, create a larger gap
      if (targetPosition < existingOrders.length - 1) {
        // Not at the end, place closer to the next item
        return afterOrder - (minimumOrderGap / 2);
      } else {
        // At the end, place after the last item
        return beforeOrder + initialStep;
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

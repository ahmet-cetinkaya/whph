class OrderRank {
  static const double MIN_ORDER = 0;
  static const double MAX_ORDER = 1000000; // Upper limit for normalization
  static const double INITIAL_STEP = 1000;
  static const double MINIMUM_GAP = 1;

  // Calculate midpoint between two orders
  static double between(double beforeOrder, double afterOrder) {
    if (beforeOrder >= afterOrder || (afterOrder - beforeOrder) < MINIMUM_GAP) {
      throw RankGapTooSmallException();
    }
    return beforeOrder + ((afterOrder - beforeOrder) / 2);
  }

  // Get order value for first position
  static double first() => INITIAL_STEP;

  // Get next available order after the given one
  static double after(double currentOrder) {
    if (currentOrder >= MAX_ORDER - INITIAL_STEP) {
      throw RankGapTooSmallException();
    }
    return currentOrder + INITIAL_STEP;
  }

  // Get next available order before the given one
  static double before(double currentOrder) {
    if (currentOrder <= INITIAL_STEP) {
      return currentOrder / 2;
    }
    return currentOrder - INITIAL_STEP;
  }

  // Find target order for moving an item to a specific position
  static double getTargetOrder(List<double> existingOrders, int targetPosition) {
    if (existingOrders.isEmpty) return INITIAL_STEP;

    // Sort to ensure we're working with ordered data
    existingOrders.sort();

    // Handle special cases
    if (targetPosition <= 0) {
      // Place at beginning - use half of first item's order to ensure it comes first
      return existingOrders.first > INITIAL_STEP ? existingOrders.first / 2 : INITIAL_STEP / 2;
    }

    if (targetPosition >= existingOrders.length) {
      // Place at end - add a significant step to the last order to ensure it comes last
      return existingOrders.last + INITIAL_STEP * 2;
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
        return afterOrder - (MINIMUM_GAP / 2);
      } else {
        // At the end, place after the last item
        return beforeOrder + INITIAL_STEP;
      }
    }
  }

  // Normalize all orders when gaps get too small
  static List<double> normalize(List<double> currentOrders) {
    if (currentOrders.isEmpty) return [];

    List<double> newOrders = [];
    double step = INITIAL_STEP;

    for (int i = 0; i < currentOrders.length; i++) {
      newOrders.add(step);
      step += INITIAL_STEP;
    }

    return newOrders;
  }
}

class RankGapTooSmallException implements Exception {
  final String message = 'Reordering needed - gaps between items too small';
}

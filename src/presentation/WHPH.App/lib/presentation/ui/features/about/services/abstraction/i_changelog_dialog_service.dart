import 'package:flutter/material.dart';

/// Interface for changelog dialog service
abstract class IChangelogDialogService {
  /// Checks if the changelog should be shown and displays it if appropriate
  Future<void> checkAndShowChangelogDialog(BuildContext context);
}

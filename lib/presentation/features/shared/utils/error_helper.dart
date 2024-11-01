import 'package:flutter/material.dart';
import 'package:whph/domain/features/shared/constants/app_theme.dart';

class ErrorHelper {
  static void showError(BuildContext context, dynamic e) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: AppTheme.errorColor));
  }
}

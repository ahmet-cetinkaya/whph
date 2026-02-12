import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:whph/features/app_usages/pages/android_app_usage_debug_page.dart';
import 'package:whph/shared/constants/app_theme.dart';

class DebugSection extends StatelessWidget {
  const DebugSection({super.key});

  @override
  Widget build(BuildContext context) {
    // Only show in debug mode and Android
    if (!kDebugMode) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(AppTheme.sizeMedium),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.1),
        border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(AppTheme.sizeSmall),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'DEBUG SECTION',
            style: TextStyle(
              color: Colors.red,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: AppTheme.sizeMedium),

          // Android App Usage Debug
          if (Platform.isAndroid)
            InkWell(
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => AndroidAppUsageDebugPage(),
                  ),
                );
              },
              child: Text(
                '→ Android App Usage Debug',
                style: TextStyle(
                  color: Colors.blue,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

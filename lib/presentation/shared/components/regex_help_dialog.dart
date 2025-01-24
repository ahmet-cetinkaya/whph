import 'package:flutter/material.dart';
import 'package:whph/presentation/shared/constants/app_theme.dart';

class RegexHelpDialog extends StatelessWidget {
  const RegexHelpDialog({super.key});

  static void show(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const RegexHelpDialog(),
    );
  }

  Widget _buildPatternExample(BuildContext context, String pattern, String description) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            pattern,
            style: AppTheme.bodyMedium.copyWith(
              fontWeight: FontWeight.bold,
              fontFamily: 'monospace',
            ),
          ),
          Text(
            description,
            style: AppTheme.bodySmall.copyWith(
              color: Theme.of(context).hintColor,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Pattern Examples'),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildPatternExample(context, '.*Chrome.*', 'Matches any window title containing "Chrome"'),
            _buildPatternExample(context, '.*Visual Studio Code.*', 'Matches any VS Code window'),
            _buildPatternExample(context, '^Chrome\$', 'Matches exactly "Chrome"'),
            _buildPatternExample(context, 'Slack|Discord', 'Matches either "Slack" or "Discord"'),
            _buildPatternExample(context, '.*\\.pdf', 'Matches any PDF file'),
            const SizedBox(height: 16),
            const Text('Tips:', style: AppTheme.bodyMedium),
            const Text('• Use ".*" to match any characters', style: AppTheme.bodySmall),
            const Text('• "^" matches start of text', style: AppTheme.bodySmall),
            const Text('• "\$" matches end of text', style: AppTheme.bodySmall),
            const Text('• "|" means OR', style: AppTheme.bodySmall),
            const Text('• "\\." matches a dot', style: AppTheme.bodySmall),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }
}

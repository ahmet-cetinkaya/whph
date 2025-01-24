import 'package:flutter/material.dart';

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
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontFamily: 'monospace',
            ),
          ),
          Text(
            description,
            style: TextStyle(
              fontSize: 13,
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
            const Text('Tips:', style: TextStyle(fontWeight: FontWeight.bold)),
            const Text('• Use ".*" to match any characters'),
            const Text('• "^" matches start of text'),
            const Text('• "\$" matches end of text'),
            const Text('• "|" means OR'),
            const Text('• "\\." matches a dot'),
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

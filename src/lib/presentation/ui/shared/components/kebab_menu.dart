import 'package:flutter/material.dart';
import 'package:whph/presentation/ui/shared/components/help_menu.dart';
import 'package:whph/presentation/ui/shared/constants/shared_translation_keys.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/main.dart';

/// A reusable kebab menu (three vertical dots) component that can integrate help functionality
/// and can be extended with additional menu items.
class KebabMenu extends StatelessWidget {
  /// Translation key for the help title (optional)
  final String? helpTitleKey;
  
  /// Translation key for the help markdown content (optional)
  final String? helpMarkdownContentKey;
  
  /// Whether to show the help menu item (defaults to true if help keys are provided)
  final bool? showHelp;
  
  /// Additional menu items to display above the help option
  final List<PopupMenuEntry<String>>? additionalMenuItems;
  
  /// Callback for handling additional menu item selections
  final void Function(String value)? onMenuItemSelected;

  final _translationService = container.resolve<ITranslationService>();

  KebabMenu({
    super.key,
    this.helpTitleKey,
    this.helpMarkdownContentKey,
    this.showHelp,
    this.additionalMenuItems,
    this.onMenuItemSelected,
  }) : assert(
          (helpTitleKey != null && helpMarkdownContentKey != null) || showHelp == false,
          'helpTitleKey and helpMarkdownContentKey must be provided if help is enabled',
        );

  /// Determines if help should be shown based on parameters
  bool get _shouldShowHelp {
    if (showHelp == false) return false;
    return helpTitleKey != null && helpMarkdownContentKey != null;
  }

  @override
  Widget build(BuildContext context) {
    // If no menu items to show, return empty container
    final hasAdditionalItems = additionalMenuItems?.isNotEmpty ?? false;
    if (!_shouldShowHelp && !hasAdditionalItems) {
      return const SizedBox.shrink();
    }

    return PopupMenuButton<String>(
      icon: Icon(Icons.more_vert, color: Theme.of(context).colorScheme.primary),
      onSelected: (value) {
        switch (value) {
          case 'show_help':
            // Handle help display
            if (_shouldShowHelp) {
              HelpMenu.showHelpModal(
                context: context,
                titleKey: helpTitleKey!,
                markdownContentKey: helpMarkdownContentKey!,
              );
            }
            break;
          default:
            // Handle additional menu items
            onMenuItemSelected?.call(value);
            break;
        }
      },
      itemBuilder: (context) => [
        // Additional menu items first (if any)
        if (additionalMenuItems != null) ...additionalMenuItems!,
        
        // Help option (at the bottom, if enabled)
        if (_shouldShowHelp)
          PopupMenuItem<String>(
            value: 'show_help',
            child: Row(
              children: [
                Icon(Icons.help_outline, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Text(_translationService.translate(SharedTranslationKeys.helpTooltip)),
              ],
            ),
          ),
      ],
    );
  }
}
import 'package:flutter/material.dart';
import 'package:whph/core/application/features/sync/models/sync_member_summary.dart';
import 'package:whph/core/application/features/sync/models/sync_result_category.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/ui/features/sync/constants/sync_translation_keys.dart';
import 'package:whph/presentation/ui/features/sync/utils/sync_result_texts.dart';
import 'package:whph/presentation/ui/shared/constants/app_theme.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_translation_service.dart';

/// What the status list says about one device besides its name: the category
/// of the last result, the repeated-failure warning (FR-017) and, for a device
/// that must pair again, the badge with its action.
class SyncMemberStatus extends StatelessWidget {
  final SyncMemberSummary member;
  final VoidCallback? onRepair;

  const SyncMemberStatus({super.key, required this.member, this.onRepair});

  static const double _hintIndent = 18; // status icon (14) + gap (4)

  bool get _needsRepairing => member.isLegacy || member.lastResult == SyncResultCategory.needsRepairing;

  @override
  Widget build(BuildContext context) {
    final translationService = container.resolve<ITranslationService>();
    final category = member.lastResult;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_needsRepairing) _buildRepairBadge(context, translationService),
        if (category != null && !_needsRepairing)
          _StatusLine(
            icon: Icons.warning_amber,
            text: SyncResultTexts.categoryText(translationService, category, member.name),
          ),
        if (category == SyncResultCategory.notReachable) _buildNotReachableHint(context, translationService),
        if (member.itemsCannotBeApplied)
          _StatusLine(
            icon: Icons.error_outline,
            text: translationService.translate(SyncTranslationKeys.syncStatusItemsCannotBeApplied),
            color: Theme.of(context).colorScheme.error,
          ),
      ],
    );
  }

  /// Aligned under the status line text, past its icon and gap.
  Widget _buildNotReachableHint(BuildContext context, ITranslationService translationService) {
    return Padding(
      padding: const EdgeInsets.only(left: _hintIndent, top: 2),
      child: Text(
        translationService.translate(SyncTranslationKeys.syncStatusNotReachableHint),
        style: AppTheme.bodySmall.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
      ),
    );
  }

  Widget _buildRepairBadge(BuildContext context, ITranslationService translationService) {
    final theme = Theme.of(context);
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: AppTheme.sizeSmall,
      children: [
        Chip(
          key: const ValueKey('needs-repair-badge'),
          avatar: Icon(Icons.link_off, size: 16, color: theme.colorScheme.onErrorContainer),
          label: Text(translationService.translate(SyncTranslationKeys.syncStatusRepairBadge)),
          backgroundColor: theme.colorScheme.errorContainer,
          labelStyle: TextStyle(color: theme.colorScheme.onErrorContainer),
          visualDensity: VisualDensity.compact,
        ),
        if (onRepair != null)
          TextButton(
            onPressed: onRepair,
            child: Text(translationService.translate(SyncTranslationKeys.syncStatusRepairAction)),
          ),
      ],
    );
  }
}

class _StatusLine extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color? color;

  const _StatusLine({required this.icon, required this.text, this.color});

  @override
  Widget build(BuildContext context) {
    final lineColor = color ?? AppTheme.warningColor;
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 14, color: lineColor),
          const SizedBox(width: 4),
          Expanded(child: Text(text, style: AppTheme.bodySmall.copyWith(color: lineColor))),
        ],
      ),
    );
  }
}

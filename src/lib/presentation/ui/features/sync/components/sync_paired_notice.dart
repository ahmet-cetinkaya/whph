import 'package:flutter/material.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/core/application/features/sync/queries/get_is_paired_query.dart';
import 'package:whph/core/domain/shared/utils/logger.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/ui/shared/components/information_card.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_translation_service.dart';

/// An information card that exists only while this device is paired (U4, U5,
/// U6): the text is about what the action does to the sync group, so an
/// unpaired device must not see it.
class SyncPairedNotice extends StatefulWidget {
  final String translationKey;

  const SyncPairedNotice({super.key, required this.translationKey});

  @override
  State<SyncPairedNotice> createState() => _SyncPairedNoticeState();
}

class _SyncPairedNoticeState extends State<SyncPairedNotice> {
  bool _isPaired = false;

  @override
  void initState() {
    super.initState();
    _loadPairedState();
  }

  Future<void> _loadPairedState() async {
    try {
      final response = await container.resolve<Mediator>().send<GetIsPairedQuery, GetIsPairedQueryResponse>(
            GetIsPairedQuery(),
          );
      if (mounted) setState(() => _isPaired = response.isPaired);
    } catch (error) {
      Logger.error('SyncPairedNotice: reading the paired state failed: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isPaired) return const SizedBox.shrink();

    return InformationCard.themed(
      context: context,
      icon: Icons.sync,
      text: container.resolve<ITranslationService>().translate(widget.translationKey),
    );
  }
}

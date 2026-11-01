import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/core/application/features/sync/commands/sync_now_command.dart';
import 'package:whph/core/application/features/sync/models/sync_result_category.dart';
import 'package:whph/core/application/features/sync/models/sync_run_report.dart';
import 'package:whph/core/application/features/sync/models/sync_status.dart';
import 'package:whph/presentation/ui/features/sync/constants/sync_translation_keys.dart';
import 'package:whph/presentation/ui/features/sync/pages/sync_devices_page/mixins/sync_status_mixin.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_translation_service.dart';

class _RecordingTranslationService extends Fake implements ITranslationService {
  final translatedKeys = <String>[];

  @override
  String translate(String key, {Map<String, String>? namedArgs}) {
    translatedKeys.add(key);
    return key;
  }
}

class _FakeMediator extends Fake implements Mediator {
  final SyncNowCommandResponse response;

  _FakeMediator(this.response);

  @override
  Future<TResponse> send<TRequest extends IRequest<TResponse>, TResponse>(TRequest request) async =>
      response as TResponse;
}

class _Host extends StatefulWidget {
  final Mediator mediator;
  final ITranslationService translationService;
  final VoidCallback onRefreshed;

  const _Host({required this.mediator, required this.translationService, required this.onRefreshed});

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> with SingleTickerProviderStateMixin, SyncStatusMixin<_Host> {
  late final AnimationController _animationController =
      AnimationController(vsync: this, duration: const Duration(seconds: 1));
  SyncStatus _status = const SyncStatus(state: SyncState.idle);

  @override
  Mediator get mediator => widget.mediator;
  @override
  ITranslationService get translationService => widget.translationService;
  @override
  AnimationController get syncButtonAnimationController => _animationController;
  @override
  SyncStatus get currentSyncStatus => _status;
  @override
  set currentSyncStatus(SyncStatus value) => _status = value;
  @override
  Future<void> Function() get onRefresh => () async => widget.onRefreshed();

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TextButton(onPressed: runManualSync, child: const Text('sync'));
}

void main() {
  Future<_RecordingTranslationService> runSyncWith(
    WidgetTester tester,
    SyncNowCommandResponse response,
    VoidCallback onRefreshed,
  ) async {
    final translations = _RecordingTranslationService();
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: _Host(mediator: _FakeMediator(response), translationService: translations, onRefreshed: onRefreshed),
      ),
    ));
    await tester.tap(find.text('sync'));
    await tester.pumpAndSettle();
    return translations;
  }

  testWidgets('a failed manual sync shows no toast but refreshes the list', (tester) async {
    var refreshCount = 0;
    final failure = SyncNowCommandResponse(
      const SyncRunReport(peers: [SyncPeerReport(memberId: 'm1', category: SyncResultCategory.notReachable)]),
    );

    final translations = await runSyncWith(tester, failure, () => refreshCount++);

    expect(translations.translatedKeys, isEmpty);
    expect(refreshCount, 1);
  });

  testWidgets('a successful manual sync shows the success toast', (tester) async {
    var refreshCount = 0;
    const success = SyncNowCommandResponse(SyncRunReport(skipped: true));

    final translations = await runSyncWith(tester, success, () => refreshCount++);

    expect(translations.translatedKeys, [SyncTranslationKeys.syncCompleted]);
    expect(refreshCount, 1);
  });
}

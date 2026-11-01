import 'package:acore/acore.dart' hide Container;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whph_sync_core/whph_sync_core.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/core/application/features/sync/commands/sync_now_command.dart';
import 'package:whph/core/application/features/sync/models/sync_result_category.dart';
import 'package:whph/core/application/features/sync/models/sync_run_report.dart';
import 'package:whph/core/application/features/sync/models/sync_status.dart';
import 'package:whph/core/application/features/sync/models/sync_member_summary.dart';
import 'package:whph/core/domain/shared/constants/app_theme.dart' as domain;
import 'package:whph/main.dart' as app_main;
import 'package:whph/presentation/ui/features/sync/components/sync_device_list_item/sync_device_list_item.dart';
import 'package:whph/presentation/ui/features/sync/constants/sync_translation_keys.dart';
import 'package:whph/presentation/ui/features/sync/pages/sync_devices_page/mixins/sync_status_mixin.dart';
import 'package:whph/presentation/ui/shared/constants/app_theme.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_theme_service.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_translation_service.dart';

class FakeTranslationService extends Fake implements ITranslationService {
  @override
  String translate(String key, {Map<String, String>? namedArgs}) => key;
}

class FakeThemeService extends Fake implements IThemeService {
  @override
  Color get primaryColor => Colors.blue;
  @override
  Color get surface0 => Colors.white;
  @override
  Color get surface1 => Colors.grey.shade100;
  @override
  Color get surface2 => Colors.grey.shade200;
  @override
  Color get surface3 => Colors.grey.shade300;
  @override
  Color get textColor => Colors.black;
  @override
  Color get secondaryTextColor => Colors.grey;
  @override
  Color get lightTextColor => Colors.white;
  @override
  Color get darkTextColor => Colors.black;
  @override
  Color get dividerColor => Colors.grey;
  @override
  Color get barrierColor => Colors.black54;
  @override
  domain.UiDensity get currentUiDensity => domain.UiDensity.normal;
}

class FakeContainer extends Fake implements IContainer {
  final translationService = FakeTranslationService();
  final themeService = FakeThemeService();

  @override
  T resolve<T>([String? name]) {
    if (T == ITranslationService) return translationService as T;
    if (T == IThemeService) return themeService as T;
    throw UnimplementedError('FakeContainer.resolve($T)');
  }
}

/// Answers [SyncNowCommand] with the report the test set up.
class FakeMediator extends Fake implements Mediator {
  SyncRunReport report = const SyncRunReport();

  @override
  Future<TResponse> send<TRequest extends IRequest<TResponse>, TResponse>(TRequest request) async =>
      SyncNowCommandResponse(report) as TResponse;
}

SyncPeerReport completePeer(String memberId) => SyncPeerReport(
      memberId: memberId,
      result: SessionComplete(SessionStats(), memberId),
    );

SyncPeerReport failedPeer(String memberId) =>
    SyncPeerReport(memberId: memberId, category: SyncResultCategory.notReachable);

/// Minimal host reproducing how `SyncDevicesPage` feeds list items from the
/// manual sync run owned by [SyncStatusMixin].
class _TestSyncDevicesHost extends StatefulWidget {
  final Mediator mediator;
  final ITranslationService translationService;
  final List<SyncMemberSummary> items;

  const _TestSyncDevicesHost({
    required this.mediator,
    required this.translationService,
    required this.items,
  });

  @override
  State<_TestSyncDevicesHost> createState() => _TestSyncDevicesHostState();
}

class _TestSyncDevicesHostState extends State<_TestSyncDevicesHost>
    with TickerProviderStateMixin, SyncStatusMixin<_TestSyncDevicesHost> {
  late final AnimationController _buttonController;
  SyncStatus _currentSyncStatus = const SyncStatus(state: SyncState.idle);

  @override
  Mediator get mediator => widget.mediator;
  @override
  ITranslationService get translationService => widget.translationService;
  @override
  AnimationController get syncButtonAnimationController => _buttonController;
  @override
  SyncStatus get currentSyncStatus => _currentSyncStatus;
  @override
  set currentSyncStatus(SyncStatus value) => _currentSyncStatus = value;
  @override
  Future<void> Function() get onRefresh => () async {};

  Future<void> sync() => runManualSync();

  @override
  void initState() {
    super.initState();
    _buttonController = AnimationController(vsync: this, duration: const Duration(seconds: 1));
  }

  @override
  void dispose() {
    _buttonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: widget.items
          .map((item) => SyncDeviceListItemWidget(
                key: ValueKey(item.memberId),
                member: item,
                onRemove: (_) {},
                lastSyncResult: lastSyncResultOf(item.memberId),
              ))
          .toList(),
    );
  }
}

void main() {
  late FakeContainer fakeContainer;
  late FakeMediator mediator;

  final deviceX = SyncMemberSummary(
    memberId: 'device-x',
    name: 'Device X',
  );
  final deviceY = SyncMemberSummary(
    memberId: 'device-y',
    name: 'Device Y',
  );

  setUpAll(() {
    fakeContainer = FakeContainer();
    app_main.container = fakeContainer;
  });

  setUp(() {
    AppTheme.resetService();
    mediator = FakeMediator();
  });

  Future<void> pumpHost(WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: _TestSyncDevicesHost(
          mediator: mediator,
          translationService: fakeContainer.translationService,
          items: [deviceX, deviceY],
        ),
      ),
    ));
    await tester.pump();
  }

  Future<void> runManualSync(WidgetTester tester, List<SyncPeerReport> peers) async {
    mediator.report = SyncRunReport(peers: peers);
    await tester.runAsync(() => tester.state<_TestSyncDevicesHostState>(find.byType(_TestSyncDevicesHost)).sync());
    await tester.pump();
  }

  Finder iconInRow(String deviceId, IconData icon) => find.descendant(
        of: find.byKey(ValueKey(deviceId)),
        matching: find.byIcon(icon),
      );

  group('SyncDeviceListItemWidget last sync result indicator', () {
    testWidgets('renders no result icon before any sync attempt this session', (tester) async {
      await pumpHost(tester);

      expect(find.byIcon(Icons.check_circle), findsNothing);
      expect(find.byIcon(Icons.warning_amber), findsNothing);
    });

    testWidgets('renders success icon only on the completed device row', (tester) async {
      await pumpHost(tester);

      await runManualSync(tester, [completePeer('device-x')]);

      expect(iconInRow('device-x', Icons.check_circle), findsOneWidget);
      expect(iconInRow('device-y', Icons.check_circle), findsNothing);
      expect(find.byIcon(Icons.warning_amber), findsNothing);
    });

    testWidgets('renders warning icon only on the errored device row', (tester) async {
      await pumpHost(tester);

      await runManualSync(tester, [failedPeer('device-y')]);

      expect(iconInRow('device-y', Icons.warning_amber), findsOneWidget);
      expect(iconInRow('device-x', Icons.warning_amber), findsNothing);
      expect(find.byIcon(Icons.check_circle), findsNothing);
    });

    testWidgets('tracks each device result independently', (tester) async {
      await pumpHost(tester);

      await runManualSync(tester, [completePeer('device-x'), failedPeer('device-y')]);

      expect(iconInRow('device-x', Icons.check_circle), findsOneWidget);
      expect(iconInRow('device-y', Icons.warning_amber), findsOneWidget);
    });

    testWidgets('uses translation keys for the indicator tooltips', (tester) async {
      await pumpHost(tester);

      await runManualSync(tester, [completePeer('device-x'), failedPeer('device-y')]);

      expect(find.byTooltip(SyncTranslationKeys.lastSyncSucceeded), findsOneWidget);
      expect(find.byTooltip(SyncTranslationKeys.lastSyncFailed), findsOneWidget);
    });
  });
}

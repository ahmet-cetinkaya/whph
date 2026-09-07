import 'dart:async';

import 'package:acore/acore.dart' hide Container;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whph/core/application/features/sync/models/paginated_sync_data.dart';
import 'package:whph/core/application/features/sync/models/sync_status.dart';
import 'package:whph/core/application/features/sync/queries/get_list_syncs_query.dart';
import 'package:whph/core/application/features/sync/services/abstraction/i_sync_service.dart';
import 'package:whph/core/domain/shared/constants/app_theme.dart' as domain;
import 'package:whph/infrastructure/android/features/sync/android_server_sync_service.dart';
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

class FakeSyncService extends Fake implements ISyncService {
  final _statusController = StreamController<SyncStatus>.broadcast();

  @override
  Stream<SyncStatus> get syncStatusStream => _statusController.stream;

  @override
  SyncStatus get currentSyncStatus => const SyncStatus(state: SyncState.idle);

  @override
  Stream<SyncProgress> get progressStream => const Stream.empty();

  @override
  Stream<bool> get onSyncComplete => const Stream.empty();

  @override
  void updateSyncStatus(SyncStatus status) => _statusController.add(status);

  void emit(SyncStatus status) => _statusController.add(status);

  void close() => _statusController.close();
}

/// Minimal host reproducing how `SyncDevicesPage` feeds list items from the
/// single page-level sync status subscription owned by [SyncStatusMixin].
class _TestSyncDevicesHost extends StatefulWidget {
  final ISyncService syncService;
  final ITranslationService translationService;
  final List<SyncDeviceListItem> items;

  const _TestSyncDevicesHost({
    required this.syncService,
    required this.translationService,
    required this.items,
  });

  @override
  State<_TestSyncDevicesHost> createState() => _TestSyncDevicesHostState();
}

class _TestSyncDevicesHostState extends State<_TestSyncDevicesHost>
    with TickerProviderStateMixin, SyncStatusMixin<_TestSyncDevicesHost> {
  late final AnimationController _iconController;
  late final AnimationController _buttonController;
  SyncStatus _currentSyncStatus = const SyncStatus(state: SyncState.idle);

  @override
  ISyncService get syncService => widget.syncService;
  @override
  ITranslationService get translationService => widget.translationService;
  @override
  AndroidServerSyncService? get serverSyncService => null;
  @override
  bool get isServerMode => false;
  @override
  AnimationController get syncIconAnimationController => _iconController;
  @override
  AnimationController get syncButtonAnimationController => _buttonController;
  @override
  SyncStatus get currentSyncStatus => _currentSyncStatus;
  @override
  set currentSyncStatus(SyncStatus value) => _currentSyncStatus = value;
  @override
  Future<void> Function() get onRefresh => () async {};

  @override
  void initState() {
    super.initState();
    _iconController = AnimationController(vsync: this, duration: const Duration(seconds: 1));
    _buttonController = AnimationController(vsync: this, duration: const Duration(seconds: 1));
    setupSyncStatusListeners();
  }

  @override
  void dispose() {
    disposeSyncStatusResources();
    _iconController.dispose();
    _buttonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: widget.items
          .map((item) => SyncDeviceListItemWidget(
                key: ValueKey(item.id),
                item: item,
                onRemove: (_) {},
                lastSyncResult: lastSyncResultOf(item.id),
              ))
          .toList(),
    );
  }
}

void main() {
  late FakeContainer fakeContainer;
  late FakeSyncService syncService;

  final deviceX = SyncDeviceListItem(
    id: 'device-x',
    fromIP: '192.168.1.2',
    toIP: '192.168.1.3',
    fromDeviceID: 'from-x',
    toDeviceID: 'to-x',
    name: 'Device X',
  );
  final deviceY = SyncDeviceListItem(
    id: 'device-y',
    fromIP: '192.168.1.4',
    toIP: '192.168.1.5',
    fromDeviceID: 'from-y',
    toDeviceID: 'to-y',
    name: 'Device Y',
  );

  setUpAll(() {
    fakeContainer = FakeContainer();
    app_main.container = fakeContainer;
  });

  setUp(() {
    AppTheme.resetService();
    syncService = FakeSyncService();
  });

  tearDown(() => syncService.close());

  Future<void> pumpHost(WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: _TestSyncDevicesHost(
          syncService: syncService,
          translationService: fakeContainer.translationService,
          items: [deviceX, deviceY],
        ),
      ),
    ));
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

      syncService.emit(const SyncStatus(state: SyncState.completed, currentDeviceId: 'device-x'));
      await tester.pump();
      // Flush the mixin's post-completion refresh timer so no timer outlives the test.
      await tester.pump(const Duration(milliseconds: 200));

      expect(iconInRow('device-x', Icons.check_circle), findsOneWidget);
      expect(iconInRow('device-y', Icons.check_circle), findsNothing);
      expect(find.byIcon(Icons.warning_amber), findsNothing);
    });

    testWidgets('renders warning icon only on the errored device row', (tester) async {
      await pumpHost(tester);

      syncService.emit(const SyncStatus(state: SyncState.error, currentDeviceId: 'device-y'));
      await tester.pump();
      // Flush the mixin's post-completion refresh timer so no timer outlives the test.
      await tester.pump(const Duration(milliseconds: 200));

      expect(iconInRow('device-y', Icons.warning_amber), findsOneWidget);
      expect(iconInRow('device-x', Icons.warning_amber), findsNothing);
      expect(find.byIcon(Icons.check_circle), findsNothing);
    });

    testWidgets('tracks each device result independently', (tester) async {
      await pumpHost(tester);

      syncService.emit(const SyncStatus(state: SyncState.completed, currentDeviceId: 'device-x'));
      syncService.emit(const SyncStatus(state: SyncState.error, currentDeviceId: 'device-y'));
      await tester.pump();
      // Flush the mixin's post-completion refresh timer so no timer outlives the test.
      await tester.pump(const Duration(milliseconds: 200));

      expect(iconInRow('device-x', Icons.check_circle), findsOneWidget);
      expect(iconInRow('device-y', Icons.warning_amber), findsOneWidget);
    });

    testWidgets('uses translation keys for the indicator tooltips', (tester) async {
      await pumpHost(tester);

      syncService.emit(const SyncStatus(state: SyncState.completed, currentDeviceId: 'device-x'));
      syncService.emit(const SyncStatus(state: SyncState.error, currentDeviceId: 'device-y'));
      await tester.pump();
      // Flush the mixin's post-completion refresh timer so no timer outlives the test.
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.byTooltip(SyncTranslationKeys.lastSyncSucceeded), findsOneWidget);
      expect(find.byTooltip(SyncTranslationKeys.lastSyncFailed), findsOneWidget);
    });
  });
}

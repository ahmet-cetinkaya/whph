import 'package:acore/acore.dart' hide Container;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:whph/core/domain/shared/constants/app_theme.dart' as domain;
import 'package:whph/main.dart' as app_main;
import 'package:whph/presentation/ui/shared/services/abstraction/i_theme_service.dart';
import 'package:whph/presentation/ui/shared/utils/overlay_notification_helper.dart';

void main() {
  setUp(() {
    app_main.container = _FakeContainer();
  });

  tearDown(OverlayNotificationHelper.hideNotification);

  /// Hands back a context that sits under the app's Overlay so the helper can
  /// insert into it without a live navigatorKey.
  Future<BuildContext> pumpHost(WidgetTester tester) async {
    late BuildContext hostContext;
    await tester.pumpWidget(MaterialApp(
      home: Builder(builder: (context) {
        hostContext = context;
        return const Scaffold(body: SizedBox.shrink());
      }),
    ));
    await tester.pumpAndSettle();
    return hostContext;
  }

  testWidgets('keeps an error on screen long past the old auto-dismiss window', (WidgetTester tester) async {
    final context = await pumpHost(tester);

    OverlayNotificationHelper.showError(context: context, message: 'sync failed');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('sync failed'), findsOneWidget);

    // The old behaviour dismissed after 5 seconds; a persistent error must
    // survive an order of magnitude more with no timer pending.
    await tester.pump(const Duration(seconds: 60));
    expect(find.text('sync failed'), findsOneWidget);
  });

  testWidgets('drops a loading notification while an error is visible', (WidgetTester tester) async {
    final context = await pumpHost(tester);

    OverlayNotificationHelper.showError(context: context, message: 'sync failed');
    await tester.pumpAndSettle();

    OverlayNotificationHelper.showLoading(context: context, message: 'syncing...');
    await tester.pumpAndSettle();

    expect(find.text('sync failed'), findsOneWidget);
    expect(find.text('syncing...'), findsNothing);
  });

  testWidgets('lets a new error replace the visible one', (WidgetTester tester) async {
    final context = await pumpHost(tester);

    OverlayNotificationHelper.showError(context: context, message: 'first failure');
    await tester.pumpAndSettle();

    OverlayNotificationHelper.showError(context: context, message: 'second failure');
    await tester.pumpAndSettle();

    expect(find.text('first failure'), findsNothing);
    expect(find.text('second failure'), findsOneWidget);
  });

  testWidgets('removes the error when the dismiss affordance is tapped', (WidgetTester tester) async {
    final context = await pumpHost(tester);

    OverlayNotificationHelper.showError(context: context, message: 'sync failed');
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();

    expect(find.text('sync failed'), findsNothing);
  });

  testWidgets('lets a non-error notification through once the error is gone', (WidgetTester tester) async {
    final context = await pumpHost(tester);

    OverlayNotificationHelper.showError(context: context, message: 'sync failed');
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();

    OverlayNotificationHelper.showInfo(context: context, message: 'all good');
    await tester.pumpAndSettle();

    expect(find.text('all good'), findsOneWidget);
  });

  testWidgets('still auto-dismisses a non-error notification', (WidgetTester tester) async {
    final context = await pumpHost(tester);

    OverlayNotificationHelper.showInfo(context: context, message: 'all good');
    await tester.pumpAndSettle();
    expect(find.text('all good'), findsOneWidget);

    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(find.text('all good'), findsNothing);
  });
}

class _MockThemeService extends Mock implements IThemeService {
  @override
  Color get primaryColor => Colors.blue;
  @override
  Color get textColor => Colors.black;
  @override
  Color get secondaryTextColor => Colors.grey;
  @override
  Color get surface1 => Colors.grey.shade100;
  @override
  Color get surface2 => Colors.grey.shade200;
  @override
  Color get surface3 => Colors.grey.shade300;
  @override
  domain.UiDensity get currentUiDensity => domain.UiDensity.normal;
}

class _FakeContainer extends Fake implements IContainer {
  final _MockThemeService themeService = _MockThemeService();

  @override
  T resolve<T>([String? name]) {
    if (T == IThemeService) return themeService as T;
    throw UnimplementedError('No test double registered for $T');
  }
}

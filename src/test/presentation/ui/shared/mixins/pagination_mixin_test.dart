import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whph/presentation/ui/shared/enums/pagination_mode.dart';
import 'package:whph/presentation/ui/shared/mixins/pagination_mixin.dart';

const double _itemHeight = 50.0;
const int _itemCount = 100;

class _Harness extends StatefulWidget implements IPaginatedWidget {
  const _Harness({super.key});

  @override
  PaginationMode get paginationMode => PaginationMode.loadMore;

  @override
  State<_Harness> createState() => _HarnessState();
}

class _HarnessState extends State<_Harness> with PaginationMixin<_Harness> {
  final ScrollController _scrollController = ScrollController();
  List<String> _items = List.generate(_itemCount, (i) => 'Item $i');
  Completer<void>? fetchCompleter;

  @override
  ScrollController get scrollController => _scrollController;

  @override
  bool get hasNextPage => false;

  @override
  Future<void> onLoadMore() async {}

  Future<void> refresh() async {
    fetchCompleter = Completer<void>();
    await fetchCompleter!.future;
    if (!mounted) return;

    final offset = captureScrollOffset();
    setState(() => _items = List.generate(_itemCount, (i) => 'Refreshed $i'));
    restoreScrollOffset(offset);
  }

  /// Public test entry point for the protected [restoreScrollOffset].
  void restore(double? offset) => restoreScrollOffset(offset);

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      controller: _scrollController,
      itemCount: _items.length,
      itemExtent: _itemHeight,
      itemBuilder: (context, index) => SizedBox(height: _itemHeight, child: Text(_items[index])),
    );
  }
}

void main() {
  late GlobalKey<_HarnessState> key;

  Future<_HarnessState> pumpHarness(WidgetTester tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    key = GlobalKey<_HarnessState>();
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: _Harness(key: key))));
    await tester.pumpAndSettle();
    return key.currentState!;
  }

  double pixels(_HarnessState state) => state.scrollController.position.pixels;

  // Post-frame callbacks only run when a frame is actually produced. Production callers invoke
  // restoreScrollOffset right after setState (which schedules one); standalone calls here must force it.
  Future<void> pumpFrame(WidgetTester tester) async {
    tester.binding.scheduleFrame();
    await tester.pump();
  }

  group('PaginationMixin scroll restore', () {
    testWidgets('restores offset while idle and clamps to maxScrollExtent', (tester) async {
      final state = await pumpHarness(tester);
      expect(pixels(state), 0);

      state.restore(400);
      await pumpFrame(tester);
      expect(pixels(state), 400);

      final maxExtent = state.scrollController.position.maxScrollExtent;
      expect(maxExtent, greaterThan(0));
      state.restore(maxExtent + 1000);
      await pumpFrame(tester);
      expect(pixels(state), maxExtent);
    });

    testWidgets('does not restore while the user is dragging', (tester) async {
      final state = await pumpHarness(tester);

      final gesture = await tester.startGesture(tester.getCenter(find.byType(ListView)));
      for (var i = 0; i < 5; i++) {
        await gesture.moveBy(const Offset(0, -40));
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(state.scrollController.position.isScrollingNotifier.value, isTrue);
      final dragged = pixels(state);
      expect(dragged, greaterThan(0));

      state.restore(0);
      await pumpFrame(tester);
      expect(pixels(state), isNot(0));
      expect(pixels(state), dragged);

      await gesture.up();
      await tester.pumpAndSettle();
      expect(pixels(state), isNot(0));
    });

    testWidgets('scroll made during an in-flight refresh is kept after the data swap', (tester) async {
      final state = await pumpHarness(tester);

      const a = 300.0;
      state.scrollController.jumpTo(a);
      await tester.pumpAndSettle();
      expect(pixels(state), a);

      final refreshFuture = state.refresh();
      await tester.pump();
      expect(state.fetchCompleter, isNotNull);

      final gesture = await tester.startGesture(tester.getCenter(find.byType(ListView)));
      for (var i = 0; i < 10; i++) {
        await gesture.moveBy(const Offset(0, -40));
        await tester.pump(const Duration(milliseconds: 16));
      }
      await gesture.up();
      await tester.pumpAndSettle();

      final b = pixels(state);
      expect(b, isNot(closeTo(a, 0.5)));

      state.fetchCompleter!.complete();
      await refreshFuture;
      await tester.pumpAndSettle();

      expect(find.text('Refreshed ${(b ~/ _itemHeight)}'), findsOneWidget);
      expect(pixels(state), closeTo(b, 0.5));
    });

    testWidgets('restoreScrollOffset(null) does nothing', (tester) async {
      final state = await pumpHarness(tester);
      state.scrollController.jumpTo(250);
      await tester.pumpAndSettle();

      state.restore(null);
      await pumpFrame(tester);
      expect(pixels(state), 250);
    });

    testWidgets('restoreScrollOffset is safe after dispose', (tester) async {
      final state = await pumpHarness(tester);

      // Scheduled before dispose; callback runs after the tree is replaced.
      state.restore(400);
      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);

      // Called on an already-disposed state.
      expect(() => state.restore(400), returnsNormally);
      await pumpFrame(tester);
      expect(tester.takeException(), isNull);
    });
  });
}

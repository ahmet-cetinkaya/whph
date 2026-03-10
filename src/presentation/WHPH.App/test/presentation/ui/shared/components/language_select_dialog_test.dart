import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whph/main.dart' as app_main;
import 'package:whph/presentation/ui/shared/components/language_select_dialog.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_translation_service.dart';
import 'package:acore/acore.dart';

class FakeTranslationService extends Fake implements ITranslationService {
  String? lastLanguageCode;

  @override
  String translate(String key, {Map<String, String>? namedArgs}) {
    return key;
  }

  @override
  String getCurrentLanguage(BuildContext context) => 'en';

  @override
  Future<void> changeLanguage(BuildContext context, String languageCode) async {
    lastLanguageCode = languageCode;
  }

  @override
  Future<void> init() async {}
}

class MockContainer extends Fake implements IContainer {
  final Map<Type, dynamic> _stubs = {};

  void stub<T>(T instance) {
    _stubs[T] = instance;
  }

  @override
  T resolve<T>() {
    if (_stubs.containsKey(T)) {
      return _stubs[T] as T;
    }
    throw UnimplementedError('MockContainer: No stub registered for $T');
  }

  @override
  IContainer get instance => this;
}

void main() {
  late MockContainer mockContainer;
  late FakeTranslationService fakeTranslationService;

  setUp(() {
    mockContainer = MockContainer();
    fakeTranslationService = FakeTranslationService();
    mockContainer.stub<ITranslationService>(fakeTranslationService);
    app_main.container = mockContainer;
  });

  Widget createTestWidget(Widget child) {
    return MaterialApp(
      home: child,
    );
  }

  group('LanguageSelectDialog', () {
    testWidgets('renders first section and basic options', (tester) async {
      await tester.pumpWidget(createTestWidget(LanguageSelectDialog()));
      await tester.pumpAndSettle();

      expect(find.text('Western Europe'), findsOneWidget);
      // We expect at least one English text (there are actually two)
      expect(find.text('English'), findsAtLeastNWidgets(1));
    });

    testWidgets('calls onLanguageChanged when a language is selected', (tester) async {
      String? selectedCode;
      await tester.pumpWidget(createTestWidget(LanguageSelectDialog(
        onLanguageChanged: (code) => selectedCode = code,
      )));

      // Tap on English (use first to avoid multiple match error)
      await tester.tap(find.text('English').first);
      await tester.pump();

      expect(selectedCode, equals('en'));
    });

    testWidgets('calls translationService.changeLanguage when onLanguageChanged is null', (tester) async {
      await tester.pumpWidget(createTestWidget(LanguageSelectDialog()));

      // Tap on English
      await tester.tap(find.text('English').first);
      await tester.pump();

      expect(fakeTranslationService.lastLanguageCode, equals('en'));
    });
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:acore/acore.dart' as acore;
import 'package:whph/presentation/ui/features/settings/components/ai_settings_tile.dart';
import 'package:whph/presentation/ui/features/settings/components/settings_menu_tile.dart';
import 'package:whph/presentation/ui/features/settings/constants/settings_translation_keys.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/main.dart' as app_main;

class _FakeTranslationService implements ITranslationService {
  @override
  Future<void> init() async {}

  @override
  String translate(String key, {Map<String, String>? namedArgs}) {
    if (key == SettingsTranslationKeys.aiTitle) return 'AI';
    if (key == SettingsTranslationKeys.mcpDescription)
      return 'Allow approved local AI agents to use selected features.';
    return key;
  }

  @override
  Future<void> changeLanguage(BuildContext context, String languageCode) async {}

  @override
  Future<void> changeLanguageWithoutNavigation(BuildContext context, String languageCode) async {}

  @override
  String getCurrentLanguage(BuildContext context) => 'en';

  @override
  Widget wrapWithTranslations(Widget child) => child;
}

class _FakeContainer extends Fake implements acore.IContainer {
  @override
  T resolve<T>([String? name]) {
    if (T == ITranslationService) return _FakeTranslationService() as T;
    throw UnimplementedError('FakeContainer.resolve($T)');
  }
}

void main() {
  setUpAll(() {
    app_main.container = _FakeContainer();
  });

  testWidgets('renders the AI tile with title and description', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: const AiSettingsTile()),
    ));

    expect(find.byType(SettingsMenuTile), findsOneWidget);
    expect(find.text('AI'), findsOneWidget);
    expect(find.text('Allow approved local AI agents to use selected features.'), findsOneWidget);
  });
}

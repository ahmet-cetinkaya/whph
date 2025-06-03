import 'package:flutter/widgets.dart';

abstract class ITranslationService {
  Future<void> init();
  String translate(String key, {Map<String, String>? namedArgs});
  Future<void> changeLanguage(BuildContext context, String languageCode);
  String getCurrentLanguage(BuildContext context);
  Widget wrapWithTranslations(Widget child);
}

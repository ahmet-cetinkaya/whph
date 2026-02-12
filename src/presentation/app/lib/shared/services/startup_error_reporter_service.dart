import 'dart:io';
import 'package:url_launcher/url_launcher.dart';
import 'package:domain/shared/constants/app_info.dart';
import 'package:whph/shared/constants/shared_translation_keys.dart';
import 'package:whph/shared/services/background_translation_service.dart';
import 'package:whph/shared/state/app_startup_error_state.dart';

/// Service for reporting app startup errors
class StartupErrorReporterService {
  final AppStartupErrorState _errorState;
  final BackgroundTranslationService _translationService;

  StartupErrorReporterService(this._errorState, this._translationService);

  /// Sends a startup error report via email
  void reportError() {
    final error = _errorState.startupError ?? 'Unknown startup error';
    final stackTrace = _errorState.startupStackTrace ?? StackTrace.empty;

    String errorBody = _translationService.translate(
      SharedTranslationKeys.errorReportTemplate,
      namedArgs: {
        'appName': AppInfo.name,
        'version': AppInfo.version,
        'device': Platform.localHostname,
        'os': Platform.operatingSystem,
        'osVersion': Platform.operatingSystemVersion,
        'error': error.toString(),
        'stackTrace': stackTrace.toString(),
      },
    );

    // Fallback if translation fails (returns the key)
    if (errorBody == SharedTranslationKeys.errorReportTemplate) {
      errorBody = '''Hi, I encountered a startup error while using the ${AppInfo.name} app.

Here's information that might help you diagnose the issue:
App Version: ${AppInfo.version}
Device Info: ${Platform.localHostname}
OS: ${Platform.operatingSystem}
OS Version: ${Platform.operatingSystemVersion}
Error Message:
```
$error
Stack Trace:
$stackTrace
```

Please help me resolve this issue.

Thanks!''';
    }

    String subject = _translationService.translate(
      SharedTranslationKeys.errorReportSubject,
      namedArgs: {'appName': AppInfo.name},
    );

    // Fallback if translation fails
    if (subject == SharedTranslationKeys.errorReportSubject) {
      subject = '${AppInfo.name} App: Startup Error Report';
    }

    final encodedSubject = Uri.encodeFull(subject);
    final encodedBody = Uri.encodeFull(errorBody).replaceAll('+', '%20');

    final emailUrl = 'mailto:${AppInfo.supportEmail}?subject=$encodedSubject&body=$encodedBody';

    launchUrl(
      Uri.parse(emailUrl),
      mode: LaunchMode.platformDefault,
    );
  }
}

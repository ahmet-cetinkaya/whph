import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:acore/acore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/core/application/features/settings/commands/export_data_command.dart';
import 'package:whph/core/domain/shared/constants/app_theme.dart';
import 'package:whph/main.dart' as app_main;
import 'package:whph/presentation/ui/features/settings/components/import_export_settings.dart';
import 'package:whph/presentation/ui/features/settings/constants/settings_translation_keys.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_theme_service.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_translation_service.dart';

/// Chinese, Japanese and Korean samples covering the ranges an export can carry.
const _cjkTitle = '任务标题 タスク 작업';

class _FakeTranslationService extends Fake implements ITranslationService {
  @override
  String translate(String key, {Map<String, String>? namedArgs}) => key;
}

class _FakeThemeService extends Fake implements IThemeService {
  final _themeController = StreamController<void>.broadcast();

  @override
  Stream<void> get themeChanges => _themeController.stream;
  @override
  ThemeData get themeData => ThemeData.light();
  @override
  Color get textColor => Colors.black;
  @override
  AppThemeMode get currentThemeMode => AppThemeMode.light;
  @override
  UiDensity get currentUiDensity => UiDensity.normal;
  @override
  Color get primaryColor => Colors.blue;
  @override
  Color get surface0 => Colors.white;
  @override
  Color get surface1 => Colors.grey[100]!;
  @override
  Color get surface2 => Colors.grey[200]!;
  @override
  Color get surface3 => Colors.grey[300]!;
  @override
  Color get secondaryTextColor => Colors.grey[700]!;
  @override
  Color get lightTextColor => Colors.white;
  @override
  Color get darkTextColor => Colors.black;
  @override
  Color get dividerColor => Colors.grey[300]!;
  @override
  Color get barrierColor => Colors.black54;
}

/// Captures the exact bytes the UI hands to the platform file service, which is
/// what any real implementation persists verbatim via `writeAsBytes`.
class _RecordingFileService extends Fake implements IFileService {
  Uint8List? savedBytes;

  @override
  Future<String?> saveFile({
    required String fileName,
    required Uint8List data,
    required String fileExtension,
    bool isTextFile = false,
  }) async {
    savedBytes = data;
    return '/tmp/$fileName';
  }
}

class _StubContainer extends Fake implements IContainer {
  final Map<Type, dynamic> _stubs = {};

  void stub<T>(T instance) => _stubs[T] = instance;

  @override
  T resolve<T>() {
    final stub = _stubs[T];
    if (stub == null) throw UnimplementedError('No stub registered for $T');
    return stub as T;
  }
}

/// Stands in for the real handler so the test stays focused on the encoding of
/// the export payload rather than on repository wiring.
class _CjkExportHandler implements IRequestHandler<ExportDataCommand, ExportDataCommandResponse> {
  @override
  Future<ExportDataCommandResponse> call(ExportDataCommand request) async {
    final extension = request.fileOption.name;
    final content = request.fileOption == ExportDataFileOptions.csv
        ? '# tasks\ntitle\n$_cjkTitle\n'
        : jsonEncode({
            'tasks': [
              {'title': _cjkTitle}
            ]
          });
    return ExportDataCommandResponse(content, 'whph_export.$extension', extension);
  }
}

void main() {
  late _RecordingFileService fileService;

  setUp(() {
    fileService = _RecordingFileService();

    final mediator = Mediator(Pipeline())
      ..registerHandler<ExportDataCommand, ExportDataCommandResponse, _CjkExportHandler>(
        () => _CjkExportHandler(),
      );

    app_main.container = _StubContainer()
      ..stub<ITranslationService>(_FakeTranslationService())
      ..stub<IThemeService>(_FakeThemeService())
      ..stub<IFileService>(fileService)
      ..stub<Mediator>(mediator);
  });

  Future<void> exportAs(WidgetTester tester, String optionLabel) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: ImportExportSettings())));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.import_export));
    await tester.pumpAndSettle();

    await tester.tap(find.text(SettingsTranslationKeys.exportTitle));
    await tester.pumpAndSettle();

    await tester.tap(find.text(optionLabel));
    await tester.pumpAndSettle();
  }

  for (final optionLabel in ['JSON', 'CSV']) {
    testWidgets('$optionLabel export encodes CJK text as UTF-8 without mojibake', (tester) async {
      await exportAs(tester, optionLabel);

      final savedBytes = fileService.savedBytes;
      expect(savedBytes, isNotNull, reason: 'export did not reach the file service');

      // Reading the exported file back the way any UTF-8 aware editor does.
      expect(utf8.decode(savedBytes!, allowMalformed: true), contains(_cjkTitle));
    });
  }
}

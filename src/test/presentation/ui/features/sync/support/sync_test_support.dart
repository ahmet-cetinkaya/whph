import 'dart:async';
import 'dart:io';

import 'package:acore/acore.dart' hide Container;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/core/domain/shared/constants/app_theme.dart' as domain;
import 'package:whph/main.dart' as app_main;
import 'package:whph/presentation/ui/shared/constants/app_theme.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_theme_service.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_translation_service.dart';
import 'package:yaml/yaml.dart';

const String _syncLocalePath = 'lib/presentation/ui/features/sync/assets/locales/en.yaml';
const String _settingsLocalePath = 'lib/presentation/ui/features/settings/assets/locales/en.yaml';

/// Translates with the real English texts of the sync and settings features, so
/// tests assert what the user reads, and a missing key shows up as the key.
class YamlTranslationService extends Fake implements ITranslationService {
  final Map<String, String> _texts = {};

  YamlTranslationService() {
    for (final path in [_syncLocalePath, _settingsLocalePath]) {
      _flatten(loadYaml(File(path).readAsStringSync()) as YamlMap, '');
    }
  }

  bool hasText(String key) => _texts.containsKey(key);

  void _flatten(YamlMap node, String prefix) {
    node.forEach((key, value) {
      final path = prefix.isEmpty ? '$key' : '$prefix.$key';
      if (value is YamlMap) {
        _flatten(value, path);
      } else {
        _texts[path] = '$value';
      }
    });
  }

  @override
  String translate(String key, {Map<String, String>? namedArgs}) {
    var text = _texts[key] ?? key;
    namedArgs?.forEach((name, value) => text = text.replaceAll('{$name}', value));
    return text;
  }
}

class _TestThemeService extends Fake implements IThemeService {
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

class _TestContainer extends Fake implements IContainer {
  final Map<Type, Object> services;

  _TestContainer(this.services);

  @override
  T resolve<T>() => (services[T] ?? (throw UnimplementedError('TestContainer.resolve($T)'))) as T;
}

class _FunctionHandler<T extends IRequest<R>, R> extends IRequestHandler<T, R> {
  final FutureOr<R> Function(T request) _handle;

  const _FunctionHandler(this._handle);

  @override
  Future<R> call(T request) async => _handle(request);
}

/// A container with the real English texts and a mediator whose handlers the
/// test defines; it records every request that was sent.
class SyncTestHarness {
  final Mediator mediator = Mediator(Pipeline());
  final YamlTranslationService translations = YamlTranslationService();
  final List<Object> sentRequests = [];

  SyncTestHarness({Map<Type, Object> extraServices = const {}}) {
    app_main.container = _TestContainer({
      ITranslationService: translations,
      IThemeService: _TestThemeService(),
      Mediator: mediator,
      ...extraServices,
    });
    AppTheme.resetService();
  }

  /// Answers requests of type [T] with [handle].
  void on<T extends IRequest<R>, R>(FutureOr<R> Function(T request) handle) {
    mediator.registerHandler<T, R, _FunctionHandler<T, R>>(
      () => _FunctionHandler<T, R>((request) {
        sentRequests.add(request);
        return handle(request);
      }),
    );
  }

  int sentCount<T>() => sentRequests.whereType<T>().length;
}

Future<void> pumpPage(WidgetTester tester, Widget child) async {
  await tester.pumpWidget(MaterialApp(home: Scaffold(body: SingleChildScrollView(child: child))));
  await tester.pump();
}

import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:acore/acore.dart';
import 'package:whph/core/application/shared/services/stream_logger.dart';

void main() {
  group('StreamLogger', () {
    late StreamController<String> controller;
    late StreamLogger logger;

    setUp(() {
      controller = StreamController<String>();
      logger = StreamLogger(controller, includeTimestamp: false, includeStackTrace: false);
    });

    tearDown(() {
      controller.close();
    });

    test('should stream debug logs', () {
      logger.debug('test message');
      expect(controller.stream, emits(contains('[DEBUG] test message')));
    });

    test('should stream info logs', () {
      logger.info('test message');
      expect(controller.stream, emits(contains('[INFO] test message')));
    });

    test('should stream warning logs', () {
      logger.warning('test message');
      expect(controller.stream, emits(contains('[WARNING] test message')));
    });

    test('should stream error logs', () {
      logger.error('test message');
      expect(controller.stream, emits(contains('[ERROR] test message')));
    });

    test('should stream fatal logs', () {
      logger.fatal('test message');
      expect(controller.stream, emits(contains('[FATAL] test message')));
    });

    test('should respect min level', () {
      logger = StreamLogger(
        controller,
        minLevel: LogLevel.warning,
        includeTimestamp: false,
        includeStackTrace: false,
      );

      logger.info('info message');
      logger.warning('warning message');

      expect(controller.stream, emits(contains('[WARNING] warning message')));
    });
  });
}

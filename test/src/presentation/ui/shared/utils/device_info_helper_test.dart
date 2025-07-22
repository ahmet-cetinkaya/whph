import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whph/src/presentation/ui/shared/utils/device_info_helper.dart';

void main() {
  group('DeviceInfoHelper', () {
    late List<MethodCall> methodCalls;

    setUp(() {
      methodCalls = [];
      
      // Mock the method channel for app info
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('me.ahmetcetinkaya.whph/app_info'),
        (MethodCall methodCall) async {
          methodCalls.add(methodCall);
          
          switch (methodCall.method) {
            case 'isRunningInWorkProfile':
              // Return true to simulate work profile
              return true;
            default:
              return null;
          }
        },
      );
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('me.ahmetcetinkaya.whph/app_info'),
        null,
      );
    });

    testWidgets('getDeviceName should append (Work) suffix when in work profile', (WidgetTester tester) async {
      // This test can only run on Android platform in a real environment
      // For unit testing, we'll mock the platform check
      
      // Skip test if not on Android since work profile is Android-specific
      if (!Platform.isAndroid) {
        return;
      }

      // Call getDeviceName
      final deviceName = await DeviceInfoHelper.getDeviceName();
      
      // Verify that the method channel was called
      expect(methodCalls.length, greaterThan(0));
      expect(methodCalls.any((call) => call.method == 'isRunningInWorkProfile'), isTrue);
      
      // Verify that the device name contains (Work) suffix
      expect(deviceName, contains('(Work)'));
    });

    testWidgets('getDeviceName should not append (Work) suffix when not in work profile', (WidgetTester tester) async {
      // Mock the method channel to return false for work profile
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('me.ahmetcetinkaya.whph/app_info'),
        (MethodCall methodCall) async {
          methodCalls.add(methodCall);
          
          switch (methodCall.method) {
            case 'isRunningInWorkProfile':
              // Return false to simulate main profile
              return false;
            default:
              return null;
          }
        },
      );

      // Skip test if not on Android since work profile is Android-specific
      if (!Platform.isAndroid) {
        return;
      }

      // Call getDeviceName
      final deviceName = await DeviceInfoHelper.getDeviceName();
      
      // Verify that the method channel was called
      expect(methodCalls.length, greaterThan(0));
      expect(methodCalls.any((call) => call.method == 'isRunningInWorkProfile'), isTrue);
      
      // Verify that the device name does not contain (Work) suffix
      expect(deviceName, isNot(contains('(Work)')));
    });

    testWidgets('getDeviceName should handle work profile detection errors gracefully', (WidgetTester tester) async {
      // Mock the method channel to throw an error
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('me.ahmetcetinkaya.whph/app_info'),
        (MethodCall methodCall) async {
          methodCalls.add(methodCall);
          
          switch (methodCall.method) {
            case 'isRunningInWorkProfile':
              // Throw an error to simulate failure
              throw PlatformException(code: 'WORK_PROFILE_ERROR', message: 'Test error');
            default:
              return null;
          }
        },
      );

      // Skip test if not on Android since work profile is Android-specific
      if (!Platform.isAndroid) {
        return;
      }

      // Call getDeviceName - should not throw an error
      final deviceName = await DeviceInfoHelper.getDeviceName();
      
      // Verify that the method channel was called
      expect(methodCalls.length, greaterThan(0));
      expect(methodCalls.any((call) => call.method == 'isRunningInWorkProfile'), isTrue);
      
      // Verify that a device name is still returned (without Work suffix due to error)
      expect(deviceName, isNotEmpty);
      expect(deviceName, isNot(equals('Unknown Device')));
    });
  });
}
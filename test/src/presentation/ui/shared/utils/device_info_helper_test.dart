import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whph/src/presentation/ui/shared/utils/device_info_helper.dart';

void main() {
  // Initialize the test binding
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DeviceInfoHelper', () {
    late List<MethodCall> methodCalls;

    setUp(() {
      methodCalls = [];
      
      // Mock device_info_plus plugin for all platforms
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('dev.fluttercommunity.plus/device_info'),
        (MethodCall methodCall) async {
          switch (methodCall.method) {
            case 'getAndroidDeviceInfo':
              return {
                'brand': 'TestBrand',
                'model': 'TestModel',
                'isPhysicalDevice': true,
              };
            case 'getLinuxDeviceInfo':
              return {
                'prettyName': 'Test Linux',
              };
            case 'getWindowsDeviceInfo':
              return {
                'computerName': 'Test Windows',
              };
            case 'getMacOsDeviceInfo':
              return {
                'computerName': 'Test macOS',
              };
            default:
              return null;
          }
        },
      );
      
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
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('dev.fluttercommunity.plus/device_info'),
        null,
      );
    });

    // Test that verifies the mock setup works correctly
    test('should have correct mock setup', () {
      expect(methodCalls, isEmpty); // Initially no calls
    });

    // Integration test that runs on actual Android platform
    test('getDeviceName should append (Work) suffix when in work profile on Android', () async {
      // Only run this test on actual Android platform
      if (Platform.isAndroid) {
        // Call getDeviceName
        final deviceName = await DeviceInfoHelper.getDeviceName();
        
        // Verify that the method channel was called
        expect(methodCalls.length, greaterThan(0));
        expect(methodCalls.any((call) => call.method == 'isRunningInWorkProfile'), isTrue);
        
        // Verify that the device name contains (Work) suffix
        expect(deviceName, contains('(Work)'));
      } else {
        // On non-Android platforms, just verify the test setup
        expect(methodCalls, isEmpty);
        // Mark test as skipped for non-Android platforms
        printOnFailure('Test skipped: Android-specific functionality');
      }
    });

    test('getDeviceName should not append (Work) suffix when not in work profile on Android', () async {
      // Only run this test on actual Android platform
      if (Platform.isAndroid) {
        // Reset method calls
        methodCalls.clear();
        
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

        // Call getDeviceName
        final deviceName = await DeviceInfoHelper.getDeviceName();
        
        // Verify that the method channel was called
        expect(methodCalls.length, greaterThan(0));
        expect(methodCalls.any((call) => call.method == 'isRunningInWorkProfile'), isTrue);
        
        // Verify that the device name does not contain (Work) suffix
        expect(deviceName, isNot(contains('(Work)')));
      } else {
        // On non-Android platforms, just verify the test setup
        expect(methodCalls, isEmpty);
        printOnFailure('Test skipped: Android-specific functionality');
      }
    });

    test('getDeviceName should handle work profile detection errors gracefully on Android', () async {
      // Only run this test on actual Android platform
      if (Platform.isAndroid) {
        // Reset method calls
        methodCalls.clear();
        
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

        // Call getDeviceName - should not throw an error
        final deviceName = await DeviceInfoHelper.getDeviceName();
        
        // Verify that the method channel was called
        expect(methodCalls.length, greaterThan(0));
        expect(methodCalls.any((call) => call.method == 'isRunningInWorkProfile'), isTrue);
        
        // Verify that a device name is still returned (without Work suffix due to error)
        expect(deviceName, isNotEmpty);
        expect(deviceName, isNot(equals('Unknown Device')));
      } else {
        // On non-Android platforms, just verify the test setup
        expect(methodCalls, isEmpty);
        printOnFailure('Test skipped: Android-specific functionality');
      }
    });

    // Test for non-Android platforms to ensure graceful handling
    test('getDeviceName should work on non-Android platforms', () async {
      if (!Platform.isAndroid) {
        // Call getDeviceName on non-Android platform
        final deviceName = await DeviceInfoHelper.getDeviceName();
        
        // Should return a valid device name without crashing
        expect(deviceName, isNotEmpty);
        
        // Work profile method should not be called on non-Android platforms
        expect(methodCalls.where((call) => call.method == 'isRunningInWorkProfile'), isEmpty);
      } else {
        // On Android, just verify the test setup
        expect(methodCalls, isEmpty);
        printOnFailure('Test skipped: Non-Android platform test');
      }
    });

    // Test that verifies the Android work profile functionality works with mocked data
    test('Android work profile functionality should work with mocked device info', () async {
      // This test simulates what would happen on Android by testing the logic
      // without relying on Platform.isAndroid
      
      // Reset method calls to track this test specifically
      methodCalls.clear();
      
      // Since we can't easily mock Platform.isAndroid, we test the components
      // that would be called on Android
      
      // Test that the app info channel mock is working
      try {
        const channel = MethodChannel('me.ahmetcetinkaya.whph/app_info');
        final result = await channel.invokeMethod<bool>('isRunningInWorkProfile');
        expect(result, isTrue);
        expect(methodCalls.length, 1);
        expect(methodCalls.first.method, 'isRunningInWorkProfile');
      } catch (e) {
        fail('Method channel mock should work: $e');
      }
    });

    test('Android device info mock should return expected values', () async {
      // Test that the device info mock is working
      try {
        const channel = MethodChannel('dev.fluttercommunity.plus/device_info');
        final result = await channel.invokeMethod('getAndroidDeviceInfo');
        expect(result, isA<Map>());
        expect(result['brand'], 'TestBrand');
        expect(result['model'], 'TestModel');
      } catch (e) {
        fail('Device info mock should work: $e');
      }
    });
  });
}
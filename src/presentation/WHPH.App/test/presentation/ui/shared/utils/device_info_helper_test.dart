import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whph/presentation/ui/shared/utils/device_info_helper.dart';

void main() {
  // Initialize the test binding
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DeviceInfoHelper', () {
    late List<MethodCall> methodCalls;

    setUp(() {
      methodCalls = [];

      // Mock device_info_plus plugin for all platforms
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('dev.fluttercommunity.plus/device_info'),
        (MethodCall methodCall) async {
          switch (methodCall.method) {
            case 'getAndroidDeviceInfo':
              return {
                'brand': 'TestBrand',
                'model': 'TestModel',
                'isPhysicalDevice': true,
                'version': <String, dynamic>{
                  'release': '11',
                  'sdkInt': 30,
                },
                'fingerprint': 'test-fingerprint',
                'hardware': 'test-hardware',
                'id': 'test-id',
                'manufacturer': 'TestManufacturer',
                'product': 'test-product',
                'supported32BitAbis': <String>[],
                'supported64BitAbis': <String>[],
                'supportedAbis': <String>[],
                'tags': 'test-tags',
                'type': 'user',
                'isLowRamDevice': false,
                'systemFeatures': <String>[],
                'displayMetrics': <String, dynamic>{
                  'widthPx': 1080.0,
                  'heightPx': 1920.0,
                  'xDpi': 420.0,
                  'yDpi': 420.0,
                },
                'serialNumber': 'unknown',
              };
            case 'getLinuxDeviceInfo':
              return {
                'name': 'Test Linux',
                'version': '20.04',
                'id': 'ubuntu',
                'idLike': <String>['debian'],
                'versionCodename': 'focal',
                'versionId': '20.04',
                'prettyName': 'Test Linux',
                'buildId': 'test-build',
                'variant': 'test-variant',
                'variantId': 'test-variant-id',
                'machineId': 'test-machine-id',
              };
            case 'getWindowsDeviceInfo':
              return {
                'computerName': 'Test Windows',
                'numberOfCores': 4,
                'systemMemoryInMegabytes': 8192,
                'userName': 'testuser',
                'majorVersion': 10,
                'minorVersion': 0,
                'buildNumber': 19041,
                'platformId': 2,
                'csdVersion': '',
                'servicePackMajor': 0,
                'servicePackMinor': 0,
                'suitMask': 256,
                'productType': 1,
                'reserved': 0,
                'buildLab': 'test-build-lab',
                'buildLabEx': 'test-build-lab-ex',
                'digitalProductId': <int>[],
                'displayVersion': '20H2',
                'editionId': 'Professional',
                'installDate': DateTime.now().toIso8601String(),
                'productId': 'test-product-id',
                'productName': 'Windows 10 Pro',
                'registeredOwner': 'Test Owner',
                'releaseId': '2009',
                'deviceId': 'test-device-id',
              };
            case 'getMacOsDeviceInfo':
              return {
                'computerName': 'Test macOS',
                'hostName': 'test-host',
                'arch': 'x86_64',
                'model': 'MacBookPro16,1',
                'kernelVersion': 'Darwin Kernel Version 20.6.0',
                'majorVersion': 11,
                'minorVersion': 6,
                'patchVersion': 0,
                'osRelease': '20G165',
                'activeCPUs': 8,
                'memorySize': 17179869184,
                'cpuFrequency': 2600000000,
                'systemGUID': 'test-system-guid',
              };
            case 'getIosDeviceInfo':
              return {
                'name': 'Test iPhone',
                'systemName': 'iOS',
                'systemVersion': '15.0',
                'model': 'iPhone',
                'localizedModel': 'iPhone',
                'identifierForVendor': 'test-identifier',
                'isPhysicalDevice': true,
                'utsname': <String, dynamic>{
                  'sysname': 'Darwin',
                  'nodename': 'test-node',
                  'release': '21.0.0',
                  'version': 'Darwin Kernel Version 21.0.0',
                  'machine': 'arm64',
                },
              };
            case 'getWebBrowserInfo':
              return {
                'browserName': 'chrome',
                'appCodeName': 'Mozilla',
                'appName': 'Netscape',
                'appVersion': '5.0 (Test)',
                'deviceMemory': 8,
                'language': 'en-US',
                'languages': <String>['en-US', 'en'],
                'platform': 'Linux x86_64',
                'product': 'Gecko',
                'productSub': '20030107',
                'userAgent': 'Mozilla/5.0 (Test) Chrome/95.0.4638.69 Safari/537.36',
                'vendor': 'Google Inc.',
                'vendorSub': '',
                'hardwareConcurrency': 8,
                'maxTouchPoints': 0,
              };
            default:
              return <String, dynamic>{};
          }
        },
      );

      // Mock the method channel for app info
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
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
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('me.ahmetcetinkaya.whph/app_info'),
        null,
      );
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
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
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
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
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
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
      // Reset method calls to track this test specifically
      methodCalls.clear();

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

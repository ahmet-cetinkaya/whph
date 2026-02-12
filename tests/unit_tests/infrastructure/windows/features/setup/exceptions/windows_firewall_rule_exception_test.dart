import 'package:flutter_test/flutter_test.dart';
import 'package:infrastructure_windows/features/setup/exceptions/windows_firewall_rule_exception.dart';

void main() {
  group('WindowsFirewallRuleException', () {
    group('constructor', () {
      test('should create exception with message only', () {
        const exception = WindowsFirewallRuleException('Test error');
        expect(exception.message, 'Test error');
        expect(exception.invalidValue, isNull);
        expect(exception.netshExitCode, isNull);
        expect(exception.netshStderr, isNull);
        expect(exception.netshStdout, isNull);
      });

      test('should create exception with all parameters', () {
        const exception = WindowsFirewallRuleException(
          'Test error',
          invalidValue: '8080',
          netshExitCode: 1,
          netshStderr: 'Error output',
          netshStdout: 'Standard output',
        );

        expect(exception.message, 'Test error');
        expect(exception.invalidValue, '8080');
        expect(exception.netshExitCode, 1);
        expect(exception.netshStderr, 'Error output');
        expect(exception.netshStdout, 'Standard output');
      });
    });

    group('toString', () {
      test('should return message only when no additional context', () {
        const exception = WindowsFirewallRuleException('Test error');
        expect(exception.toString(), 'Test error');
      });

      test('should include invalid value in output', () {
        const exception = WindowsFirewallRuleException(
          'Test error',
          invalidValue: 'invalid_port',
        );
        expect(exception.toString(), contains('Test error'));
        expect(exception.toString(), contains('[InvalidValue: invalid_port]'));
      });

      test('should include netsh exit code in output', () {
        const exception = WindowsFirewallRuleException(
          'Test error',
          netshExitCode: 1,
        );
        expect(exception.toString(), contains('Test error'));
        expect(exception.toString(), contains('[Netsh ExitCode: 1]'));
      });

      test('should include netsh stderr in output', () {
        const exception = WindowsFirewallRuleException(
          'Test error',
          netshStderr: 'Access denied',
        );
        expect(exception.toString(), contains('Test error'));
        expect(exception.toString(), contains('[Netsh Error: Access denied]'));
      });

      test('should include all context when provided', () {
        const exception = WindowsFirewallRuleException(
          'Test error',
          invalidValue: '8080',
          netshExitCode: 1,
          netshStderr: 'Access denied',
        );

        final output = exception.toString();
        expect(output, contains('Test error'));
        expect(output, contains('[InvalidValue: 8080]'));
        expect(output, contains('[Netsh ExitCode: 1]'));
        expect(output, contains('[Netsh Error: Access denied]'));
      });

      test('should not include netsh stdout in toString', () {
        const exception = WindowsFirewallRuleException(
          'Test error',
          netshStdout: 'Standard output',
        );
        // stdout is stored but not included in toString
        expect(exception.toString(), equals('Test error'));
        expect(exception.netshStdout, 'Standard output');
      });
    });

    group('exception interface', () {
      test('should implement Exception', () {
        const exception = WindowsFirewallRuleException('Test');
        expect(exception, isA<Exception>());
      });

      test('should be throwable and catchable', () {
        expect(
          () => throw const WindowsFirewallRuleException('Test'),
          throwsA(isA<WindowsFirewallRuleException>()),
        );
      });
    });
  });
}

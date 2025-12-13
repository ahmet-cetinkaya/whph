/// Custom exception for Windows firewall rule operations with detailed context
class WindowsFirewallRuleException implements Exception {
  final String message;
  final String? invalidValue;
  final int? netshExitCode;
  final String? netshStderr;
  final String? netshStdout;

  const WindowsFirewallRuleException(
    this.message, {
    this.invalidValue,
    this.netshExitCode,
    this.netshStderr,
    this.netshStdout,
  });

  @override
  String toString() {
    final buffer = StringBuffer(message);
    if (invalidValue != null) buffer.write(' [InvalidValue: $invalidValue]');
    if (netshExitCode != null) buffer.write(' [Netsh ExitCode: $netshExitCode]');
    if (netshStderr != null) buffer.write(' [Netsh Error: $netshStderr]');
    return buffer.toString();
  }
}

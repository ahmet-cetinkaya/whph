/// Custom exception for firewall rule operations with detailed context.
class LinuxFirewallRuleException implements Exception {
  final String message;
  final String? invalidValue;
  final int? ufwExitCode;
  final String? ufwStderr;
  final String? ufwStdout;

  const LinuxFirewallRuleException(
    this.message, {
    this.invalidValue,
    this.ufwExitCode,
    this.ufwStderr,
    this.ufwStdout,
  });

  @override
  String toString() {
    final buffer = StringBuffer(message);
    if (invalidValue != null) buffer.write(' [InvalidValue: $invalidValue]');
    if (ufwExitCode != null) buffer.write(' [UFW ExitCode: $ufwExitCode]');
    if (ufwStderr != null) buffer.write(' [UFW Error: $ufwStderr]');
    return buffer.toString();
  }
}

/// Formats errors and stack traces for the email error report.
///
/// Reports arrive as a `mailto:` body, so what these functions omit is
/// permanently lost — a user cannot be asked to re-run the crash.
library;

/// Marker written when an error is reported without a stack trace, so the
/// report shows the trace is genuinely absent rather than looking truncated.
const String noStackTraceMarker = '<no stack trace captured>';

/// Number of leading stack frames kept in a report. Platform `mailto:` handlers
/// silently truncate long URLs, and a truncated report loses its tail — the
/// frames nearest the failure, which sit at the top, are the ones worth keeping.
const int _maxStackTraceLines = 50;

/// Describes [error] including its runtime type.
///
/// `Error.toString()` omits the type — a `_TypeError` renders as the bare text
/// "Null check operator used on a null value", which tells us the operator that
/// failed but not that it was a `TypeError`. Reports arrived unattributable
/// without it.
String describeError(Object? error) {
  if (error == null) return 'Unknown error';
  return '${error.runtimeType}: $error';
}

/// Describes [stackTrace], trimmed to the frames nearest the failure.
///
/// Returns [noStackTraceMarker] when the trace is absent or empty.
String describeStackTrace(StackTrace? stackTrace) {
  final trace = stackTrace?.toString().trim() ?? '';
  if (trace.isEmpty) return noStackTraceMarker;

  final lines = trace.split('\n');
  if (lines.length <= _maxStackTraceLines) return trace;

  final omitted = lines.length - _maxStackTraceLines;
  return [
    ...lines.take(_maxStackTraceLines),
    '... $omitted more frame(s) omitted',
  ].join('\n');
}

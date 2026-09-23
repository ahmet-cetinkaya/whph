import 'package:whph/core/application/features/mcp/services/abstraction/i_mcp_access_service.dart';
import 'package:whph/core/application/features/mcp/services/abstraction/i_mcp_server_service.dart';
import 'package:whph/core/application/shared/services/abstraction/i_application_shutdown_service.dart';
import 'package:whph/core/application/shared/services/abstraction/i_single_instance_service.dart';
import 'package:whph/core/application/shared/services/abstraction/i_timer_session_service.dart';

class ApplicationShutdownService implements IApplicationShutdownService {
  final ITimerSessionService _timerSessionService;
  final IMcpServerService _mcpServerService;
  final IMcpAccessService _mcpAccessService;
  final ISingleInstanceService? _singleInstanceService;
  Future<void>? _shutdown;

  ApplicationShutdownService({
    required ITimerSessionService timerSessionService,
    required IMcpServerService mcpServerService,
    required IMcpAccessService mcpAccessService,
    ISingleInstanceService? singleInstanceService,
  })  : _timerSessionService = timerSessionService,
        _mcpServerService = mcpServerService,
        _mcpAccessService = mcpAccessService,
        _singleInstanceService = singleInstanceService;

  @override
  Future<void> shutdown() => _shutdown ??= _performShutdown();

  Future<void> _performShutdown() async {
    Object? firstError;
    StackTrace? firstStackTrace;

    Future<void> run(Future<void> Function() cleanup) async {
      try {
        await cleanup();
      } catch (error, stackTrace) {
        firstError ??= error;
        firstStackTrace ??= stackTrace;
      }
    }

    await run(_timerSessionService.shutdown);
    await run(_mcpServerService.stop);
    await run(_mcpAccessService.dispose);
    final singleInstanceService = _singleInstanceService;
    if (singleInstanceService != null) {
      await run(singleInstanceService.releaseInstance);
    }

    if (firstError != null) {
      Error.throwWithStackTrace(
        ApplicationShutdownException(firstError!),
        firstStackTrace!,
      );
    }
  }
}

class ApplicationShutdownException implements Exception {
  final Object cause;

  const ApplicationShutdownException(this.cause);

  @override
  String toString() => 'Application shutdown did not complete cleanly: $cause';
}

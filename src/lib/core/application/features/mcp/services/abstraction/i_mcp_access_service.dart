import 'dart:async';

abstract final class McpScopes {
  static const tasksRead = 'tasks:read';
  static const tasksWrite = 'tasks:write';
  static const tasksDelete = 'tasks:delete';
  static const habitsRead = 'habits:read';
  static const habitsWrite = 'habits:write';
  static const habitsDelete = 'habits:delete';
  static const notesRead = 'notes:read';
  static const notesWrite = 'notes:write';
  static const notesDelete = 'notes:delete';
  static const tagsRead = 'tags:read';
  static const tagsWrite = 'tags:write';
  static const tagsDelete = 'tags:delete';
  static const timersRead = 'timers:read';
  static const timersWrite = 'timers:write';
  static const usageRead = 'usage:read';
  static const usageWrite = 'usage:write';
  static const usageDelete = 'usage:delete';
  static const usageTrack = 'usage:track';
  static const settingsRead = 'settings:read';
  static const settingsWrite = 'settings:write';
  static const syncRead = 'sync:read';
  static const syncManage = 'sync:manage';
  static const overviewRead = 'overview:read';
  static const appRead = 'app:read';
  static const dataExport = 'data:export';
  static const dataImport = 'data:import';

  static const all = <String>{
    tasksRead,
    tasksWrite,
    tasksDelete,
    habitsRead,
    habitsWrite,
    habitsDelete,
    notesRead,
    notesWrite,
    notesDelete,
    tagsRead,
    tagsWrite,
    tagsDelete,
    timersRead,
    timersWrite,
    usageRead,
    usageWrite,
    usageDelete,
    usageTrack,
    settingsRead,
    settingsWrite,
    syncRead,
    syncManage,
    overviewRead,
    appRead,
    dataExport,
    dataImport,
  };
}

class McpServerPreferences {
  final bool isEnabled;
  final int port;
  final String transferDirectory;

  const McpServerPreferences({
    required this.isEnabled,
    required this.port,
    required this.transferDirectory,
  });
}

class McpAccessGrant {
  final String id;
  final String clientName;
  final String tokenDigest;
  final Set<String> scopes;
  final DateTime createdAt;
  final DateTime? rotatedAt;
  final DateTime? revokedAt;

  McpAccessGrant({
    required this.id,
    required this.clientName,
    required this.tokenDigest,
    required Set<String> scopes,
    required this.createdAt,
    required this.rotatedAt,
    required this.revokedAt,
  }) : scopes = Set.unmodifiable(scopes);

  bool get isRevoked => revokedAt != null;
}

class McpAccessState {
  final McpServerPreferences preferences;
  final List<McpAccessGrant> grants;

  McpAccessState({required this.preferences, required List<McpAccessGrant> grants})
      : grants = List.unmodifiable(grants);
}

class McpIssuedGrant {
  final McpAccessGrant grant;
  final String token;

  const McpIssuedGrant({required this.grant, required this.token});
}

class McpAuthenticatedGrant {
  final String id;
  final String clientName;
  final Set<String> scopes;

  McpAuthenticatedGrant({required this.id, required this.clientName, required Set<String> scopes})
      : scopes = Set.unmodifiable(scopes);
}

class McpAccessRevocation {
  final String grantId;

  const McpAccessRevocation({required this.grantId});
}

class McpAccessStorageException implements Exception {
  final String message;

  const McpAccessStorageException(this.message);

  @override
  String toString() => 'McpAccessStorageException: $message';
}

abstract class IMcpAccessService {
  Stream<McpAccessRevocation> get revocations;

  Future<McpAccessState> readState();

  Future<void> setPreferences(McpServerPreferences preferences);

  Future<McpIssuedGrant> createGrant({required String clientName, required Set<String> scopes});

  Future<McpIssuedGrant> rotateGrant(String grantId);

  Future<void> revokeGrant(String grantId);

  Future<McpAuthenticatedGrant?> authenticate(
    String token, {
    Set<String> requiredScopes = const {},
  });

  Future<void> dispose();
}

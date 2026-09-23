import 'dart:convert';
import 'dart:io';

import 'package:collection/collection.dart';
import 'package:path/path.dart' as p;
import 'package:whph/core/application/features/mcp/services/abstraction/i_mcp_access_service.dart';
import 'package:whph/core/application/shared/services/abstraction/i_application_directory_service.dart';

const _documentVersion = 1;
const _maximumDocumentBytes = 1024 * 1024;
const _ownerDirectoryMode = '700';
const _ownerFileMode = '600';

class McpAccessStore {
  final IApplicationDirectoryService _applicationDirectoryService;
  Future<void> _writeQueue = Future.value();

  McpAccessStore({required IApplicationDirectoryService applicationDirectoryService})
      : _applicationDirectoryService = applicationDirectoryService;

  Future<McpAccessState> load() async {
    try {
      final paths = await _resolvePaths();
      if (!await paths.file.exists()) return _defaultState(paths.directory);
      await _rejectLink(paths.file.path, 'access document');
      await _validateOwnerOnly(paths.directory.path, _ownerDirectoryMode);
      await _validateOwnerOnly(paths.file.path, _ownerFileMode);
      final bytes = await paths.file.readAsBytes();
      if (bytes.length > _maximumDocumentBytes) {
        throw const FormatException('Access document is too large');
      }
      return _decodeState(utf8.decode(bytes));
    } on McpAccessStorageException {
      rethrow;
    } on Object {
      throw const McpAccessStorageException('MCP access settings could not be read safely');
    }
  }

  Future<T> update<T>(Future<(McpAccessState, T)> Function(McpAccessState current) operation) {
    final result = _writeQueue.then((_) async {
      final current = await load();
      final update = await operation(current);
      await _save(update.$1);
      return update.$2;
    });
    _writeQueue = result.then<void>((_) {}, onError: (_) {});
    return result;
  }

  Future<void> _save(McpAccessState state) async {
    File? temporaryFile;
    try {
      final paths = await _resolvePaths();
      _validateState(state);
      await _prepareDirectory(paths.directory);
      await _rejectLink(paths.file.path, 'access document');
      final timestamp = DateTime.now().microsecondsSinceEpoch;
      temporaryFile = File('${paths.file.path}.$pid.$timestamp.tmp');
      await _rejectLink(temporaryFile.path, 'temporary access document');
      await temporaryFile.writeAsString(_encodeState(state), flush: true);
      await _setOwnerOnly(temporaryFile.path, _ownerFileMode);
      await temporaryFile.rename(paths.file.path);
      temporaryFile = null;
    } on McpAccessStorageException {
      rethrow;
    } on Object {
      throw const McpAccessStorageException('MCP access settings could not be saved safely');
    } finally {
      try {
        if (temporaryFile != null && await temporaryFile.exists()) {
          await temporaryFile.delete();
        }
      } on Object {
        throw const McpAccessStorageException('Temporary MCP access settings could not be removed safely');
      }
    }
  }

  Future<_AccessPaths> _resolvePaths() async {
    final applicationDirectory = await _applicationDirectoryService.getApplicationDirectory();
    final absoluteApplicationPath = p.normalize(p.absolute(applicationDirectory.path));
    _validateWindowsApplicationDirectory(absoluteApplicationPath);
    final directory = Directory(p.join(absoluteApplicationPath, 'mcp'));
    return _AccessPaths(directory, File(p.join(directory.path, 'access.json')));
  }

  Future<void> _prepareDirectory(Directory directory) async {
    await _rejectLink(directory.path, 'access directory');
    await directory.create(recursive: true);
    await _rejectLink(directory.path, 'access directory');
    await _setOwnerOnly(directory.path, _ownerDirectoryMode);
  }

  Future<void> _rejectLink(String path, String description) async {
    final type = await FileSystemEntity.type(path, followLinks: false);
    if (type == FileSystemEntityType.link) {
      throw McpAccessStorageException('MCP $description must not be a symbolic link');
    }
  }

  Future<void> _setOwnerOnly(String path, String mode) async {
    if (Platform.isWindows) return;
    final result = await Process.run('chmod', [mode, path]);
    if (result.exitCode != 0) {
      throw const McpAccessStorageException('MCP access permissions could not be secured');
    }
  }

  Future<void> _validateOwnerOnly(String path, String expectedMode) async {
    if (Platform.isWindows) return;
    final permissions = (await FileStat.stat(path)).mode & 0x1ff;
    if (permissions != int.parse(expectedMode, radix: 8)) {
      throw const McpAccessStorageException('MCP access permissions are not owner-only');
    }
  }

  void _validateWindowsApplicationDirectory(String applicationPath) {
    if (!Platform.isWindows) return;
    final userRoots = [Platform.environment['APPDATA'], Platform.environment['LOCALAPPDATA']]
        .whereType<String>()
        .map((root) => p.normalize(p.absolute(root)));
    if (!userRoots.any((root) => applicationPath == root || p.isWithin(root, applicationPath))) {
      throw const McpAccessStorageException('MCP access settings require the current user application directory');
    }
  }

  McpAccessState _defaultState(Directory directory) => McpAccessState(
        preferences: McpServerPreferences(
          isEnabled: false,
          port: 44041,
          transferDirectory: p.join(directory.path, 'transfers'),
        ),
        grants: const [],
      );

  McpAccessState _decodeState(String source) {
    final decoded = jsonDecode(source);
    if (decoded is! Map<String, dynamic> || decoded['version'] != _documentVersion) {
      throw const FormatException('Unsupported MCP access document');
    }
    final preferencesJson = _stringMap(decoded['preferences']);
    final grantsJson = decoded['grants'];
    if (grantsJson is! List) throw const FormatException('Invalid grants');
    final state = McpAccessState(
      preferences: McpServerPreferences(
        isEnabled: _boolean(preferencesJson['isEnabled']),
        port: _integer(preferencesJson['port']),
        transferDirectory: _string(preferencesJson['transferDirectory']),
      ),
      grants: grantsJson.map((value) => _decodeGrant(_stringMap(value))).toList(growable: false),
    );
    _validateState(state);
    if (!p.isAbsolute(state.preferences.transferDirectory)) {
      throw const FormatException('Transfer directory must be absolute');
    }
    return state;
  }

  McpAccessGrant _decodeGrant(Map<String, dynamic> json) {
    final scopeValues = json['scopes'];
    if (scopeValues is! List || scopeValues.any((scope) => scope is! String)) {
      throw const FormatException('Invalid scopes');
    }
    return McpAccessGrant(
      id: _string(json['id']),
      clientName: _string(json['clientName']),
      tokenDigest: _string(json['tokenDigest']),
      scopes: scopeValues.cast<String>().toSet(),
      createdAt: _dateTime(json['createdAt']),
      rotatedAt: _nullableDateTime(json['rotatedAt']),
      revokedAt: _nullableDateTime(json['revokedAt']),
    );
  }

  String _encodeState(McpAccessState state) => jsonEncode({
        'version': _documentVersion,
        'preferences': {
          'isEnabled': state.preferences.isEnabled,
          'port': state.preferences.port,
          'transferDirectory': state.preferences.transferDirectory,
        },
        'grants': state.grants
            .map((grant) => {
                  'id': grant.id,
                  'clientName': grant.clientName,
                  'tokenDigest': grant.tokenDigest,
                  'scopes': grant.scopes.sorted(),
                  'createdAt': grant.createdAt.toUtc().toIso8601String(),
                  'rotatedAt': grant.rotatedAt?.toUtc().toIso8601String(),
                  'revokedAt': grant.revokedAt?.toUtc().toIso8601String(),
                })
            .toList(growable: false),
      });

  void _validateState(McpAccessState state) {
    final preferences = state.preferences;
    if (preferences.port < 1 || preferences.port > 65535 || !p.isAbsolute(preferences.transferDirectory)) {
      throw ArgumentError('Invalid MCP server preferences');
    }
    final ids = <String>{};
    for (final grant in state.grants) {
      if (grant.id.isEmpty || !ids.add(grant.id) || !_isValidClientName(grant.clientName)) {
        throw const FormatException('Invalid MCP access grant metadata');
      }
      if (grant.scopes.isEmpty || !McpScopes.all.containsAll(grant.scopes)) {
        throw const FormatException('Invalid MCP access grant scopes');
      }
      final digest = base64Url.decode(base64Url.normalize(grant.tokenDigest));
      if (digest.length != 32) throw const FormatException('Invalid MCP access token digest');
    }
  }

  bool _isValidClientName(String value) =>
      value == value.trim() &&
      value.isNotEmpty &&
      value.length <= 100 &&
      !value.runes.any((rune) => rune < 32 || rune == 127);

  Map<String, dynamic> _stringMap(Object? value) {
    if (value is! Map<String, dynamic>) throw const FormatException('Invalid MCP access document object');
    return value;
  }

  String _string(Object? value) {
    if (value is! String) throw const FormatException('Invalid MCP access document string');
    return value;
  }

  int _integer(Object? value) {
    if (value is! int) throw const FormatException('Invalid MCP access document integer');
    return value;
  }

  bool _boolean(Object? value) {
    if (value is! bool) throw const FormatException('Invalid MCP access document boolean');
    return value;
  }

  DateTime _dateTime(Object? value) {
    final source = _string(value);
    if (!source.endsWith('Z')) throw const FormatException('MCP access timestamps must use UTC');
    return DateTime.parse(source);
  }

  DateTime? _nullableDateTime(Object? value) => value == null ? null : _dateTime(value);
}

class _AccessPaths {
  final Directory directory;
  final File file;

  const _AccessPaths(this.directory, this.file);
}

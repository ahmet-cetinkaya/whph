import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:whph/core/application/features/mcp/services/abstraction/i_mcp_access_service.dart';
import 'package:whph/infrastructure/shared/features/mcp/mcp_access_store.dart';

const _tokenByteLength = 32;
const _grantIdByteLength = 16;
const _maximumTokenCharacterLength = 128;

class McpAccessService implements IMcpAccessService {
  final McpAccessStore _store;
  final Random _random;
  final DateTime Function() _now;
  final StreamController<McpAccessRevocation> _revocations = StreamController.broadcast();

  McpAccessService({
    required McpAccessStore store,
    Random? random,
    DateTime Function()? now,
  })  : _store = store,
        _random = random ?? Random.secure(),
        _now = now ?? DateTime.now;

  @override
  Stream<McpAccessRevocation> get revocations => _revocations.stream;

  @override
  Future<McpAccessState> readState() => _store.load();

  @override
  Future<void> setPreferences(McpServerPreferences preferences) async {
    _validatePreferences(preferences);
    await _store.update<Object?>((current) async => (
          McpAccessState(preferences: preferences, grants: current.grants),
          null,
        ));
  }

  @override
  Future<McpIssuedGrant> createGrant({required String clientName, required Set<String> scopes}) {
    _validateClientName(clientName);
    _validateScopes(scopes, allowEmpty: false);
    return _store.update((current) async {
      final token = _randomValue(_tokenByteLength);
      final grant = McpAccessGrant(
        id: _randomValue(_grantIdByteLength),
        clientName: clientName,
        tokenDigest: _digest(token),
        scopes: scopes,
        createdAt: _now().toUtc(),
        rotatedAt: null,
        revokedAt: null,
      );
      return (
        McpAccessState(
          preferences: current.preferences,
          grants: [...current.grants, grant],
        ),
        McpIssuedGrant(grant: grant, token: token),
      );
    });
  }

  @override
  Future<McpIssuedGrant> rotateGrant(String grantId) async {
    if (grantId.isEmpty) throw ArgumentError.value(grantId, 'grantId');
    final issued = await _store.update((current) async {
      final index = current.grants.indexWhere((grant) => grant.id == grantId && !grant.isRevoked);
      if (index < 0) throw StateError('Active MCP access grant was not found');
      final token = _randomValue(_tokenByteLength);
      final existing = current.grants[index];
      final rotated = McpAccessGrant(
        id: existing.id,
        clientName: existing.clientName,
        tokenDigest: _digest(token),
        scopes: existing.scopes,
        createdAt: existing.createdAt,
        rotatedAt: _now().toUtc(),
        revokedAt: null,
      );
      final grants = current.grants.map((grant) => grant.id == grantId ? rotated : grant).toList(growable: false);
      return (
        McpAccessState(preferences: current.preferences, grants: grants),
        McpIssuedGrant(grant: rotated, token: token),
      );
    });
    if (!_revocations.isClosed) {
      _revocations.add(McpAccessRevocation(grantId: grantId));
    }
    return issued;
  }

  @override
  Future<void> revokeGrant(String grantId) async {
    if (grantId.isEmpty) throw ArgumentError.value(grantId, 'grantId');
    await _store.update<Object?>((current) async {
      final index = current.grants.indexWhere((grant) => grant.id == grantId && !grant.isRevoked);
      if (index < 0) throw StateError('Active MCP access grant was not found');
      final existing = current.grants[index];
      final revoked = McpAccessGrant(
        id: existing.id,
        clientName: existing.clientName,
        tokenDigest: existing.tokenDigest,
        scopes: existing.scopes,
        createdAt: existing.createdAt,
        rotatedAt: existing.rotatedAt,
        revokedAt: _now().toUtc(),
      );
      final grants = current.grants.map((grant) => grant.id == grantId ? revoked : grant).toList(growable: false);
      return (
        McpAccessState(preferences: current.preferences, grants: grants),
        null,
      );
    });
    if (!_revocations.isClosed) {
      _revocations.add(McpAccessRevocation(grantId: grantId));
    }
  }

  @override
  Future<McpAuthenticatedGrant?> authenticate(
    String token, {
    Set<String> requiredScopes = const {},
  }) async {
    if (token.isEmpty || token.length > _maximumTokenCharacterLength) return null;
    try {
      _validateScopes(requiredScopes, allowEmpty: true);
      final candidateDigest = sha256.convert(utf8.encode(token)).bytes;
      final current = await _store.load();
      for (final grant in current.grants) {
        final storedDigest = base64Url.decode(base64Url.normalize(grant.tokenDigest));
        final matches = _constantTimeEquals(candidateDigest, storedDigest);
        if (matches && !grant.isRevoked && grant.scopes.containsAll(requiredScopes)) {
          return McpAuthenticatedGrant(id: grant.id, clientName: grant.clientName, scopes: grant.scopes);
        }
      }
      return null;
    } on McpAccessStorageException {
      return null;
    }
  }

  @override
  Future<void> dispose() => _revocations.close();

  String _randomValue(int byteLength) {
    final bytes = List<int>.generate(byteLength, (_) => _random.nextInt(256), growable: false);
    return base64UrlEncode(bytes).replaceAll('=', '');
  }

  String _digest(String token) => base64UrlEncode(sha256.convert(utf8.encode(token)).bytes);

  bool _constantTimeEquals(List<int> left, List<int> right) {
    if (left.length != _tokenByteLength || right.length != _tokenByteLength) return false;
    var difference = 0;
    for (var index = 0; index < _tokenByteLength; index++) {
      difference |= left[index] ^ right[index];
    }
    return difference == 0;
  }

  void _validateClientName(String value) {
    final hasControlCharacters = value.runes.any((rune) => rune < 32 || rune == 127);
    if (value != value.trim() || value.isEmpty || value.length > 100 || hasControlCharacters) {
      throw ArgumentError.value(value, 'clientName', 'Must be 1-100 trimmed printable characters');
    }
  }

  void _validateScopes(Set<String> scopes, {required bool allowEmpty}) {
    if ((!allowEmpty && scopes.isEmpty) || !McpScopes.all.containsAll(scopes)) {
      throw ArgumentError.value(scopes, 'scopes', 'Contains an unknown or missing MCP scope');
    }
  }

  void _validatePreferences(McpServerPreferences preferences) {
    if (preferences.port < 1 || preferences.port > 65535 || !p.isAbsolute(preferences.transferDirectory)) {
      throw ArgumentError.value(preferences, 'preferences', 'Port and transfer directory are invalid');
    }
  }
}

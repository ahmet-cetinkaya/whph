import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:whph/core/application/features/mcp/services/abstraction/i_mcp_access_service.dart';
import 'package:whph/core/application/features/mcp/services/abstraction/i_mcp_data_transfer_service.dart';
import 'package:whph/core/application/shared/services/abstraction/i_application_directory_service.dart';

const mcpMaximumTransferInputBytes = 100 * 1024 * 1024;
const mcpMaximumTransferUnpackedBytes = 500 * 1024 * 1024;
const mcpMaximumArtifactChunkBytes = 256 * 1024;
// At most 128 short-lived records fit comfortably in this 64 KiB document.
const mcpMaximumTransferMetadataBytes = 64 * 1024;
const mcpMaximumRetainedTransferMetadataEntries = 128;
const _maximumStagedImportsPerClient = 5;
const _artifactLifetime = Duration(hours: 1);
const _stagingLifetime = Duration(minutes: 15);

final class McpStagedImport {
  const McpStagedImport({
    required this.id,
    required this.ownerGrantId,
    required this.path,
    required this.sizeBytes,
    required this.sha256,
    required this.expiresAt,
  });

  final String id;
  final String ownerGrantId;
  final String path;
  final int sizeBytes;
  final String sha256;
  final DateTime expiresAt;
}

final class McpTransferFileStore {
  McpTransferFileStore({
    required IApplicationDirectoryService applicationDirectoryService,
    required IMcpAccessService accessService,
    DateTime Function()? now,
    Random? random,
    Future<void> Function()? beforeSaveIndex,
  })  : _applicationDirectoryService = applicationDirectoryService,
        _accessService = accessService,
        _now = now ?? DateTime.now,
        _random = random ?? Random.secure(),
        _beforeSaveIndex = beforeSaveIndex;

  final IApplicationDirectoryService _applicationDirectoryService;
  final IMcpAccessService _accessService;
  final DateTime Function() _now;
  final Random _random;
  final Future<void> Function()? _beforeSaveIndex;
  Map<String, _StoredArtifact> _artifacts = const {};
  Map<String, McpStagedImport> _stagedImports = const {};
  bool _isLoaded = false;
  Future<void> _mutationTail = Future.value();

  Future<T> _runLocked<T>(Future<T> Function() operation) {
    final result = _mutationTail.then((_) => operation());
    _mutationTail = result.then<void>((_) {}, onError: (error, stackTrace) {});
    return result;
  }

  Future<McpTransferArtifact> storeExport({
    required String clientGrantId,
    required String fileName,
    required String fileExtension,
    required Object content,
  }) =>
      _runLocked(() => _storeExportLocked(
            clientGrantId: clientGrantId,
            fileName: fileName,
            fileExtension: fileExtension,
            content: content,
          ));

  Future<McpTransferArtifact> _storeExportLocked({
    required String clientGrantId,
    required String fileName,
    required String fileExtension,
    required Object content,
  }) async {
    await _ensureLoadedLocked();
    await _cleanupExpiredLocked();
    _ensureMetadataEntryCapacity(admitting: true);
    final directory = await _privateDirectory('artifacts');
    final id = _newId();
    final file = File(p.join(directory.path, id));
    final digest = _DigestSink();
    final digestInput = sha256.startChunkedConversion(digest);
    var size = 0;
    final sink = file.openWrite(mode: FileMode.writeOnly);
    try {
      final chunks = switch (content) {
        String value => Stream<List<int>>.value(utf8.encode(value)),
        List<int> value => Stream<List<int>>.value(value),
        _ => throw ArgumentError.value(
            content, 'content', 'Unsupported export content'),
      };
      await for (final chunk in chunks) {
        size += chunk.length;
        if (size > mcpMaximumTransferInputBytes) {
          throw const FileSystemException('Export exceeds the transfer limit');
        }
        digestInput.add(chunk);
        sink.add(chunk);
      }
      digestInput.close();
      await sink.flush();
      await sink.close();
      if (!Platform.isWindows) await _chmod(file.path, '400');
    } catch (_) {
      digestInput.close();
      await sink.close();
      if (await file.exists()) await file.delete();
      rethrow;
    }
    final expiresAt = _now().toUtc().add(_artifactLifetime);
    final metadata = McpTransferArtifact(
      id: id,
      ownerGrantId: clientGrantId,
      fileName: p.basename(fileName),
      fileExtension: fileExtension,
      sizeBytes: size,
      sha256: digest.value.toString(),
      expiresAt: expiresAt,
    );
    _artifacts = Map.unmodifiable({
      ..._artifacts,
      id: _StoredArtifact(metadata: metadata, path: file.path),
    });
    try {
      await _saveIndexLocked();
    } catch (_) {
      _artifacts = Map.unmodifiable({
        for (final entry in _artifacts.entries)
          if (entry.key != id) entry.key: entry.value,
      });
      await _delete(file.path);
      rethrow;
    }
    return metadata;
  }

  Future<McpStagedImport> stageImport({
    required String clientGrantId,
    required String sourceName,
  }) =>
      _runLocked(() => _stageImportLocked(
            clientGrantId: clientGrantId,
            sourceName: sourceName,
          ));

  Future<McpStagedImport> _stageImportLocked({
    required String clientGrantId,
    required String sourceName,
  }) async {
    await _ensureLoadedLocked();
    await _cleanupExpiredLocked();
    _validateBasename(sourceName);
    final activeCount = _stagedImports.values
        .where((item) => item.ownerGrantId == clientGrantId)
        .length;
    if (activeCount >= _maximumStagedImportsPerClient) {
      throw const FileSystemException('Too many staged imports');
    }
    _ensureMetadataEntryCapacity(admitting: true);
    final preferences = (await _accessService.readState()).preferences;
    await _validateLocalTransferDirectory(preferences.transferDirectory);
    final transferDirectoryType = await FileSystemEntity.type(
      preferences.transferDirectory,
      followLinks: false,
    );
    if (transferDirectoryType == FileSystemEntityType.notFound) {
      throw const McpTransferSourceMissingException();
    }
    if (transferDirectoryType != FileSystemEntityType.directory) {
      throw const FileSystemException(
          'Transfer directory must be a real directory');
    }
    final source = File(p.join(preferences.transferDirectory, sourceName));
    final sourceType =
        await FileSystemEntity.type(source.path, followLinks: false);
    if (sourceType == FileSystemEntityType.notFound) {
      throw const McpTransferSourceMissingException();
    }
    if (sourceType != FileSystemEntityType.file) {
      throw const FileSystemException('Import source must be a regular file');
    }
    if (await source.length() > mcpMaximumTransferInputBytes) {
      throw const FileSystemException('Import exceeds the transfer limit');
    }
    final stagingDirectory = await _privateDirectory('staging');
    final id = _newId();
    final temporary = File(p.join(stagingDirectory.path, '$id.tmp'));
    final staged = File(p.join(stagingDirectory.path, id));
    final copy = await _boundedCopy(source, temporary);
    await temporary.rename(staged.path);
    if (!Platform.isWindows) await _chmod(staged.path, '400');
    final result = McpStagedImport(
      id: id,
      ownerGrantId: clientGrantId,
      path: staged.path,
      sizeBytes: copy.$1,
      sha256: copy.$2,
      expiresAt: _now().toUtc().add(_stagingLifetime),
    );
    _stagedImports = Map.unmodifiable({..._stagedImports, id: result});
    try {
      await _saveIndexLocked();
    } catch (_) {
      _stagedImports = Map.unmodifiable({
        for (final entry in _stagedImports.entries)
          if (entry.key != id) entry.key: entry.value,
      });
      await _delete(staged.path);
      rethrow;
    }
    return result;
  }

  Future<McpArtifactChunk?> readArtifactChunk({
    required String clientGrantId,
    required String artifactId,
    required int offset,
    int length = mcpMaximumArtifactChunkBytes,
  }) =>
      _runLocked(() => _readArtifactChunkLocked(
            clientGrantId: clientGrantId,
            artifactId: artifactId,
            offset: offset,
            length: length,
          ));

  Future<McpArtifactChunk?> _readArtifactChunkLocked({
    required String clientGrantId,
    required String artifactId,
    required int offset,
    required int length,
  }) async {
    await _ensureLoadedLocked();
    if (offset < 0) throw ArgumentError.value(offset, 'offset');
    if (length < 1 || length > mcpMaximumArtifactChunkBytes) {
      throw ArgumentError.value(length, 'length');
    }
    await _cleanupExpiredLocked();
    final stored = _artifacts[artifactId];
    if (stored == null || stored.metadata.ownerGrantId != clientGrantId) {
      return null;
    }
    final artifactFile = File(stored.path);
    if (await FileSystemEntity.type(
          artifactFile.path,
          followLinks: false,
        ) !=
        FileSystemEntityType.file) return null;
    if (!Platform.isWindows && !await _hasMode(artifactFile.path, 0x100)) {
      return null;
    }
    final actual = await _hashBounded(artifactFile);
    if (actual.$1 != stored.metadata.sizeBytes ||
        actual.$2 != stored.metadata.sha256) return null;
    if (offset > stored.metadata.sizeBytes) {
      throw ArgumentError.value(offset, 'offset', 'Beyond artifact length');
    }
    final end = min(
      stored.metadata.sizeBytes,
      offset + length,
    );
    final bytes =
        await artifactFile.openRead(offset, end).expand((e) => e).toList();
    return McpArtifactChunk(
      artifact: stored.metadata,
      offset: offset,
      bytes: bytes,
      nextOffset: end < stored.metadata.sizeBytes ? end : null,
    );
  }

  Future<bool> verifyStaged(McpStagedImport staged) async {
    if (!staged.expiresAt.isAfter(_now().toUtc())) return false;
    final file = File(staged.path);
    if (await FileSystemEntity.type(file.path, followLinks: false) !=
        FileSystemEntityType.file) return false;
    final digest = await _hashBounded(file);
    return digest.$1 == staged.sizeBytes && digest.$2 == staged.sha256;
  }

  Future<List<int>> readStaged(McpStagedImport staged) async {
    if (!await verifyStaged(staged)) {
      throw const FileSystemException('Staged import changed or expired');
    }
    return File(staged.path).readAsBytes();
  }

  Future<void> removeStaged(McpStagedImport staged) =>
      _runLocked(() => _removeStagedLocked(staged));

  Future<void> _removeStagedLocked(McpStagedImport staged) async {
    await _ensureLoadedLocked();
    await _delete(staged.path);
    _stagedImports = Map.unmodifiable({
      for (final entry in _stagedImports.entries)
        if (entry.key != staged.id) entry.key: entry.value,
    });
    await _saveIndexLocked();
  }

  Future<void> validateWhphEnvelopeAndSize(McpStagedImport staged) async {
    if (!await verifyStaged(staged)) {
      throw const FormatException('Staged import changed or expired');
    }
    if (staged.sizeBytes < 16) {
      throw const FormatException('Invalid WHPH file');
    }
    final file = File(staged.path);
    final header = await file.openRead(0, 16).expand((chunk) => chunk).toList();
    if (ascii.decode(header.take(4).toList(), allowInvalid: true) != 'WHPH') {
      throw const FormatException('Invalid WHPH file');
    }
    final fields = Uint8List.fromList(header).buffer.asByteData();
    if (fields.getUint32(4, Endian.little) != 1) {
      throw const FormatException('Unsupported WHPH version');
    }
    final compressedLength = fields.getUint32(12, Endian.little);
    if (compressedLength != staged.sizeBytes - 16) {
      throw const FormatException('Invalid WHPH data length');
    }
    var unpackedBytes = 0;
    await for (final chunk in ZLibDecoder(gzip: true).bind(file.openRead(16))) {
      unpackedBytes += chunk.length;
      if (unpackedBytes > mcpMaximumTransferUnpackedBytes) {
        throw const FormatException('WHPH content exceeds the unpacked limit');
      }
    }
  }

  Future<void> cleanupExpired() => _runLocked(_cleanupExpiredLocked);

  Future<void> _cleanupExpiredLocked() async {
    await _ensureLoadedLocked();
    final now = _now().toUtc();
    final expiredArtifactIds = _artifacts.entries
        .where((entry) => !entry.value.metadata.expiresAt.isAfter(now))
        .map((entry) => entry.key)
        .toSet();
    final expiredStagingIds = _stagedImports.entries
        .where((entry) => !entry.value.expiresAt.isAfter(now))
        .map((entry) => entry.key)
        .toSet();
    if (expiredArtifactIds.isEmpty && expiredStagingIds.isEmpty) return;

    final previousArtifacts = _artifacts;
    final previousStagedImports = _stagedImports;
    final stagedFiles = <(String, String)>[];
    try {
      for (final id in expiredArtifactIds) {
        final path = _artifacts[id]!.path;
        final pendingPath = '$path.${_newId()}.pending-delete';
        if (await File(path).exists()) {
          await File(path).rename(pendingPath);
          stagedFiles.add((path, pendingPath));
        }
      }
      for (final id in expiredStagingIds) {
        final path = _stagedImports[id]!.path;
        final pendingPath = '$path.${_newId()}.pending-delete';
        if (await File(path).exists()) {
          await File(path).rename(pendingPath);
          stagedFiles.add((path, pendingPath));
        }
      }
      _artifacts = Map.unmodifiable({
        for (final entry in _artifacts.entries)
          if (!expiredArtifactIds.contains(entry.key)) entry.key: entry.value,
      });
      _stagedImports = Map.unmodifiable({
        for (final entry in _stagedImports.entries)
          if (!expiredStagingIds.contains(entry.key)) entry.key: entry.value,
      });
      await _saveIndexLocked();
    } catch (_) {
      _artifacts = previousArtifacts;
      _stagedImports = previousStagedImports;
      Object? restorationError;
      StackTrace? restorationStackTrace;
      for (final (path, pendingPath) in stagedFiles.reversed) {
        try {
          if (await File(pendingPath).exists()) {
            await File(pendingPath).rename(path);
          }
        } catch (error, stackTrace) {
          restorationError ??= error;
          restorationStackTrace ??= stackTrace;
        }
      }
      if (restorationError != null) {
        Error.throwWithStackTrace(restorationError, restorationStackTrace!);
      }
      rethrow;
    }
    await Future.wait(stagedFiles.map((file) => _delete(file.$2)));
  }

  Future<void> _ensureLoadedLocked() async {
    if (_isLoaded) return;
    _isLoaded = true;
    try {
      final applicationDirectory =
          await _applicationDirectoryService.getApplicationDirectory();
      final index =
          File(p.join(applicationDirectory.path, 'mcp', 'transfers.json'));
      if (!await index.exists()) return;
      if (!Platform.isWindows) {
        if (!await _hasMode(index.parent.path, 0x1c0) ||
            !await _hasMode(index.path, 0x180)) {
          throw const FileSystemException(
              'Transfer metadata permissions are not private');
        }
      }
      if (await index.length() > mcpMaximumTransferMetadataBytes) {
        throw const FormatException('Transfer metadata exceeds the limit');
      }
      final decoded = jsonDecode(await index.readAsString());
      if (decoded is! Map<String, dynamic> || decoded['version'] != 1) {
        throw const FormatException('Invalid transfer metadata');
      }
      final artifactDirectory =
          p.join(applicationDirectory.path, 'mcp', 'artifacts');
      final stagingDirectory =
          p.join(applicationDirectory.path, 'mcp', 'staging');
      final artifacts = decoded['artifacts'];
      final staging = decoded['staging'];
      if (artifacts is! List ||
          staging is! List ||
          artifacts.length + staging.length >
              mcpMaximumRetainedTransferMetadataEntries) {
        throw const FormatException('Invalid transfer metadata');
      }
      final decodedArtifacts = artifacts
          .map((value) => _decodeArtifact(value, artifactDirectory))
          .toList(growable: false);
      final decodedStaging = staging
          .map((value) => _decodeStaged(value, stagingDirectory))
          .toList(growable: false);
      _artifacts = Map.unmodifiable({
        for (final artifact in decodedArtifacts) artifact.metadata.id: artifact,
      });
      _stagedImports = Map.unmodifiable({
        for (final staged in decodedStaging) staged.id: staged,
      });
    } catch (_) {
      _isLoaded = false;
      rethrow;
    }
  }

  Future<void> _saveIndexLocked() async {
    await _beforeSaveIndex?.call();
    _ensureMetadataEntryCapacity();
    final encoded = utf8.encode(jsonEncode({
      'version': 1,
      'artifacts': _artifacts.values
          .map((item) => {
                'id': item.metadata.id,
                'ownerGrantId': item.metadata.ownerGrantId,
                'fileName': item.metadata.fileName,
                'fileExtension': item.metadata.fileExtension,
                'sizeBytes': item.metadata.sizeBytes,
                'sha256': item.metadata.sha256,
                'expiresAt': item.metadata.expiresAt.toIso8601String(),
              })
          .toList(growable: false),
      'staging': _stagedImports.values
          .map((item) => {
                'id': item.id,
                'ownerGrantId': item.ownerGrantId,
                'sizeBytes': item.sizeBytes,
                'sha256': item.sha256,
                'expiresAt': item.expiresAt.toIso8601String(),
              })
          .toList(growable: false),
    }));
    if (encoded.length > mcpMaximumTransferMetadataBytes) {
      throw const FileSystemException('Transfer metadata exceeds the limit');
    }
    final applicationDirectory =
        await _applicationDirectoryService.getApplicationDirectory();
    final directory = Directory(p.join(applicationDirectory.path, 'mcp'));
    await directory.create(recursive: true);
    if (!Platform.isWindows) await _chmod(directory.path, '700');
    final index = File(p.join(directory.path, 'transfers.json'));
    final temporary = File('${index.path}.$pid.${_newId()}.tmp');
    try {
      await temporary.writeAsBytes(encoded, flush: true);
      if (!Platform.isWindows) await _chmod(temporary.path, '600');
      await temporary.rename(index.path);
    } finally {
      if (await temporary.exists()) await temporary.delete();
    }
  }

  void _ensureMetadataEntryCapacity({bool admitting = false}) {
    if (_artifacts.length + _stagedImports.length + (admitting ? 1 : 0) >
        mcpMaximumRetainedTransferMetadataEntries) {
      throw const FileSystemException('Transfer metadata entry limit reached');
    }
  }

  _StoredArtifact _decodeArtifact(Object? value, String directory) {
    final json = Map<String, dynamic>.from(value as Map);
    final id = json['id'] as String;
    _validateOpaqueId(id);
    final metadata = McpTransferArtifact(
      id: id,
      ownerGrantId: json['ownerGrantId'] as String,
      fileName: p.basename(json['fileName'] as String),
      fileExtension: json['fileExtension'] as String,
      sizeBytes: json['sizeBytes'] as int,
      sha256: json['sha256'] as String,
      expiresAt: DateTime.parse(json['expiresAt'] as String).toUtc(),
    );
    _validateMetadata(
        metadata.ownerGrantId, metadata.sizeBytes, metadata.sha256);
    return _StoredArtifact(
      metadata: metadata,
      path: p.join(directory, id),
    );
  }

  McpStagedImport _decodeStaged(Object? value, String directory) {
    final json = Map<String, dynamic>.from(value as Map);
    final id = json['id'] as String;
    _validateOpaqueId(id);
    final staged = McpStagedImport(
      id: id,
      ownerGrantId: json['ownerGrantId'] as String,
      path: p.join(directory, id),
      sizeBytes: json['sizeBytes'] as int,
      sha256: json['sha256'] as String,
      expiresAt: DateTime.parse(json['expiresAt'] as String).toUtc(),
    );
    _validateMetadata(staged.ownerGrantId, staged.sizeBytes, staged.sha256);
    return staged;
  }

  void _validateOpaqueId(String id) {
    if (!RegExp(r'^[A-Za-z0-9_-]{32}$').hasMatch(id)) {
      throw const FormatException('Invalid transfer identifier');
    }
  }

  void _validateMetadata(String ownerGrantId, int sizeBytes, String digest) {
    if (ownerGrantId.isEmpty ||
        sizeBytes < 0 ||
        sizeBytes > mcpMaximumTransferInputBytes ||
        !RegExp(r'^[a-f0-9]{64}$').hasMatch(digest)) {
      throw const FormatException('Invalid transfer metadata');
    }
  }

  Future<(int, String)> _boundedCopy(File source, File target) async {
    final sink = target.openWrite(mode: FileMode.writeOnly);
    final digest = _DigestSink();
    final digestInput = sha256.startChunkedConversion(digest);
    var size = 0;
    try {
      await for (final chunk in source.openRead()) {
        size += chunk.length;
        if (size > mcpMaximumTransferInputBytes) {
          throw const FileSystemException('Import exceeds the transfer limit');
        }
        digestInput.add(chunk);
        sink.add(chunk);
      }
      digestInput.close();
      await sink.flush();
      await sink.close();
      return (size, digest.value.toString());
    } catch (_) {
      digestInput.close();
      await sink.close();
      if (await target.exists()) await target.delete();
      rethrow;
    }
  }

  Future<(int, String)> _hashBounded(File file) async {
    final digest = _DigestSink();
    final digestInput = sha256.startChunkedConversion(digest);
    var size = 0;
    await for (final chunk in file.openRead()) {
      size += chunk.length;
      if (size > mcpMaximumTransferInputBytes) return (size, '');
      digestInput.add(chunk);
    }
    digestInput.close();
    return (size, digest.value.toString());
  }

  Future<Directory> _privateDirectory(String name) async {
    final applicationDirectory =
        await _applicationDirectoryService.getApplicationDirectory();
    final directory = Directory(p.join(applicationDirectory.path, 'mcp', name));
    final type =
        await FileSystemEntity.type(directory.path, followLinks: false);
    if (type == FileSystemEntityType.link) {
      throw const FileSystemException(
          'Private transfer directory must not be a link');
    }
    await directory.create(recursive: true);
    if (!Platform.isWindows) await _chmod(directory.path, '700');
    return directory;
  }

  void _validateBasename(String sourceName) {
    if (sourceName.isEmpty ||
        sourceName == '.' ||
        sourceName == '..' ||
        p.basename(sourceName) != sourceName ||
        p.isAbsolute(sourceName) ||
        sourceName.contains('/') ||
        sourceName.contains('\\')) {
      throw ArgumentError.value(sourceName, 'sourceName', 'Must be a basename');
    }
  }

  Future<void> _validateLocalTransferDirectory(String path) async {
    if (!p.isAbsolute(path) ||
        path.startsWith(r'\\') ||
        path.startsWith('//')) {
      throw const FileSystemException('Transfer directory must be local');
    }
    if (!Platform.isLinux && !Platform.isAndroid) return;
    final mounts = File('/proc/mounts');
    if (!await mounts.exists()) return;
    final normalized = p.normalize(path);
    String? matchingType;
    var matchingLength = -1;
    await for (final line in mounts
        .openRead()
        .transform(utf8.decoder)
        .transform(const LineSplitter())) {
      final fields = line.split(' ');
      if (fields.length < 3) continue;
      final mountPoint = fields[1].replaceAll(r'\040', ' ');
      if ((normalized == mountPoint || p.isWithin(mountPoint, normalized)) &&
          mountPoint.length > matchingLength) {
        matchingLength = mountPoint.length;
        matchingType = fields[2];
      }
    }
    if (const {
      'nfs',
      'nfs4',
      'cifs',
      'smbfs',
      'sshfs',
      'fuse.sshfs',
      '9p',
    }.contains(matchingType)) {
      throw const FileSystemException('Transfer directory must be local');
    }
  }

  Future<void> _chmod(String path, String mode) async {
    final result = await Process.run('chmod', [mode, path]);
    if (result.exitCode != 0) {
      throw const FileSystemException('Transfer permissions failed');
    }
  }

  Future<bool> _hasMode(String path, int expectedMode) async =>
      (await FileStat.stat(path)).mode & 0x1ff == expectedMode;

  Future<void> _delete(String path) async {
    final file = File(path);
    if (await file.exists()) await file.delete();
  }

  String _newId() => base64UrlEncode(
        List<int>.generate(24, (_) => _random.nextInt(256), growable: false),
      ).replaceAll('=', '');
}

final class _StoredArtifact {
  const _StoredArtifact({required this.metadata, required this.path});

  final McpTransferArtifact metadata;
  final String path;
}

final class McpTransferSourceMissingException implements Exception {
  const McpTransferSourceMissingException();
}

final class _DigestSink implements Sink<Digest> {
  Digest? _value;

  Digest get value => _value ?? (throw StateError('Digest is not complete'));

  @override
  void add(Digest data) => _value = data;

  @override
  void close() {}
}

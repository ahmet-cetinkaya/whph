import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

const ownerDirectoryMode = '700';
const ownerFileMode = '600';

const _permissionBitsMask = 0x1ff;
const _octalRadix = 8;
const _posixReadOnlyFlag = 0;
const _posixInvalidDescriptor = -1;
const _temporaryFileSuffix = '.tmp';

/// An owner-only file operation failed; [message] never contains file content.
class OwnerOnlyFileException implements Exception {
  final String message;
  const OwnerOnlyFileException(this.message);

  @override
  String toString() => 'OwnerOnlyFileException: $message';
}

Future<void> rejectSymbolicLink(String path, String description) async {
  final type = await FileSystemEntity.type(path, followLinks: false);
  if (type == FileSystemEntityType.link) {
    throw OwnerOnlyFileException('$description must not be a symbolic link');
  }
}

Future<void> setOwnerOnlyMode(String path, String mode, String subject) async {
  if (Platform.isWindows) return;
  final result = await Process.run('chmod', [mode, path]);
  if (result.exitCode != 0) {
    throw OwnerOnlyFileException('$subject permissions could not be secured');
  }
}

Future<void> requireOwnerOnlyMode(String path, String mode, String subject) async {
  if (Platform.isWindows) return;
  final permissions = (await FileStat.stat(path)).mode & _permissionBitsMask;
  if (permissions != int.parse(mode, radix: _octalRadix)) {
    throw OwnerOnlyFileException('$subject permissions are not owner-only');
  }
}

/// Makes a rename durable by syncing the directory that holds the new name.
typedef DirectorySyncer = Future<void> Function(String directoryPath);

typedef _OpenNative = Int32 Function(Pointer<Uint8>, Int32);
typedef _OpenDart = int Function(Pointer<Uint8>, int);
typedef _FsyncNative = Int32 Function(Int32);
typedef _FsyncDart = int Function(int);
typedef _CloseNative = Int32 Function(Int32);
typedef _CloseDart = int Function(int);
typedef _MallocNative = Pointer<Uint8> Function(IntPtr);
typedef _MallocDart = Pointer<Uint8> Function(int);
typedef _FreeNative = Void Function(Pointer<Uint8>);
typedef _FreeDart = void Function(Pointer<Uint8>);

/// `fsync` on the directory (Linux and Android) through libc. Windows commits
/// the rename with `MoveFileEx` write-through inside the platform rename, so
/// it has no directory sync.
Future<void> syncDirectoryWithPosix(String directoryPath) async {
  if (Platform.isWindows) return;
  final libc = DynamicLibrary.process();
  final malloc = libc.lookupFunction<_MallocNative, _MallocDart>('malloc');
  final free = libc.lookupFunction<_FreeNative, _FreeDart>('free');
  final open = libc.lookupFunction<_OpenNative, _OpenDart>('open');
  final fsync = libc.lookupFunction<_FsyncNative, _FsyncDart>('fsync');
  final close = libc.lookupFunction<_CloseNative, _CloseDart>('close');
  final pathBytes = utf8.encode(directoryPath);
  final nativePath = malloc(pathBytes.length + 1);
  try {
    nativePath.asTypedList(pathBytes.length + 1)
      ..setAll(0, pathBytes)
      ..[pathBytes.length] = 0;
    final descriptor = open(nativePath, _posixReadOnlyFlag);
    if (descriptor == _posixInvalidDescriptor) {
      throw const OwnerOnlyFileException('directory could not be opened for sync');
    }
    try {
      if (fsync(descriptor) != 0) throw const OwnerOnlyFileException('directory could not be synced');
    } finally {
      close(descriptor);
    }
  } finally {
    free(nativePath);
  }
}

/// Writes a file atomically and owner-only: the temp file is created empty,
/// set to 0600, and only then receives bytes; the bytes are flushed to disk,
/// the temp file is renamed over the target and the directory is synced.
/// A failure at any step leaves the previous target untouched.
class OwnerOnlyAtomicWriter {
  final DirectorySyncer _syncDirectory;

  /// Called after the temp file has its final mode and before any byte is
  /// written (tests inspect the mode here).
  final Future<void> Function(String temporaryPath)? onTemporaryReady;

  /// Called after the bytes are flushed and before the rename (tests simulate
  /// a crash here).
  final Future<void> Function(String temporaryPath)? beforeRename;

  OwnerOnlyAtomicWriter({
    DirectorySyncer syncDirectory = syncDirectoryWithPosix,
    this.onTemporaryReady,
    this.beforeRename,
  }) : _syncDirectory = syncDirectory;

  Future<void> write(File target, List<int> bytes, {required String subject}) async {
    await rejectSymbolicLink(target.path, subject);
    final temporary = File('${target.path}.$pid.${DateTime.now().microsecondsSinceEpoch}$_temporaryFileSuffix');
    try {
      await temporary.create(exclusive: true);
      await setOwnerOnlyMode(temporary.path, ownerFileMode, subject);
      await onTemporaryReady?.call(temporary.path);
      await _writeAndFlush(temporary, bytes);
      await beforeRename?.call(temporary.path);
      await temporary.rename(target.path);
      await _syncDirectory(target.parent.path);
    } finally {
      if (await temporary.exists()) await temporary.delete();
    }
  }

  Future<void> _writeAndFlush(File file, List<int> bytes) async {
    final handle = await file.open(mode: FileMode.write);
    try {
      await handle.writeFrom(bytes);
      await handle.flush();
    } finally {
      await handle.close();
    }
  }
}

/// Deletes [target] and every leftover temp file of an interrupted write.
Future<void> deleteWithTemporaryFiles(File target) async {
  if (await target.exists()) await target.delete();
  final prefix = '${target.uri.pathSegments.last}.';
  if (!await target.parent.exists()) return;
  await for (final entity in target.parent.list(followLinks: false)) {
    final name = entity.uri.pathSegments.where((segment) => segment.isNotEmpty).last;
    if (entity is File && name.startsWith(prefix) && name.endsWith(_temporaryFileSuffix)) {
      await entity.delete();
    }
  }
}

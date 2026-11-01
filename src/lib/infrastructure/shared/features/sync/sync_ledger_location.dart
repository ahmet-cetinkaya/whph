import 'dart:io';

import 'package:path/path.dart' as p;

/// Packaging targets whose ledger placement U11 requires to be verified.
enum SyncPackagingTarget { linux, flatpak, windows, android }

/// Where the sync ledger sits relative to the app data directory.
enum SyncLedgerPlacement {
  /// A per-user state directory outside the data directory (U11): restoring
  /// the data directory alone does not restore the ledger.
  separateStateDirectory,

  /// Android app-private storage; the ledger is not secret and the location
  /// is the data directory there.
  appPrivate,

  /// The sandbox offers no separate state directory. The ledger stays in the
  /// data directory and the target falls under the accepted full-rollback
  /// residual risk (U11).
  insideDataDirectory,
}

class SyncLedgerLocation {
  final Directory directory;
  final SyncLedgerPlacement placement;

  const SyncLedgerLocation(this.directory, this.placement);

  /// Whether this target belongs to the accepted full-rollback residual risk.
  bool get isAcceptedFullRollbackRisk => placement == SyncLedgerPlacement.insideDataDirectory;
}

const _linuxStateFolder = 'state';
const _windowsVendorFolder = 'WHPH';

/// The target the running process belongs to. Flatpak sets `FLATPAK_ID`.
SyncPackagingTarget detectSyncPackagingTarget(Map<String, String> environment) {
  if (Platform.isAndroid) return SyncPackagingTarget.android;
  if (Platform.isWindows) return SyncPackagingTarget.windows;
  final isFlatpak = (environment['FLATPAK_ID'] ?? '').isNotEmpty;
  return isFlatpak ? SyncPackagingTarget.flatpak : SyncPackagingTarget.linux;
}

/// Resolves the injected ledger directory per platform (U11, F4):
/// Linux `$XDG_STATE_HOME/whph` (`~/.local/state/whph` fallback), Windows
/// `%LOCALAPPDATA%\WHPH\state`, Android app-private storage, and Flatpak the
/// sandbox `$XDG_STATE_HOME/whph` when it is set and separate from the data
/// directory.
SyncLedgerLocation resolveSyncLedgerLocation({
  required SyncPackagingTarget target,
  required Directory dataDirectory,
  required Map<String, String> environment,
  String folderName = 'whph',
  p.Context? pathContext,
}) {
  if (target == SyncPackagingTarget.android) {
    return SyncLedgerLocation(dataDirectory, SyncLedgerPlacement.appPrivate);
  }
  final path = pathContext ?? p.context;
  final candidate = switch (target) {
    SyncPackagingTarget.linux => _linuxStateDirectory(environment, folderName, path, requireExplicitHome: false),
    SyncPackagingTarget.flatpak => _linuxStateDirectory(environment, folderName, path, requireExplicitHome: true),
    SyncPackagingTarget.windows => _windowsStateDirectory(environment, path),
    SyncPackagingTarget.android => null,
  };
  if (candidate == null || _overlaps(candidate, dataDirectory.path, path)) {
    return SyncLedgerLocation(dataDirectory, SyncLedgerPlacement.insideDataDirectory);
  }
  return SyncLedgerLocation(Directory(candidate), SyncLedgerPlacement.separateStateDirectory);
}

String? _linuxStateDirectory(
  Map<String, String> environment,
  String folderName,
  p.Context path, {
  required bool requireExplicitHome,
}) {
  final stateHome = environment['XDG_STATE_HOME'] ?? '';
  if (stateHome.isNotEmpty && path.isAbsolute(stateHome)) return path.join(stateHome, folderName);
  // Inside Flatpak the real home is outside the sandbox's writable area.
  if (requireExplicitHome) return null;
  final home = environment['HOME'] ?? '';
  if (home.isEmpty) return null;
  return path.join(home, '.local', _linuxStateFolder, folderName);
}

String? _windowsStateDirectory(Map<String, String> environment, p.Context path) {
  final localAppData = environment['LOCALAPPDATA'] ?? '';
  if (localAppData.isEmpty) return null;
  return path.join(localAppData, _windowsVendorFolder, _linuxStateFolder);
}

bool _overlaps(String candidate, String dataDirectory, p.Context path) {
  final normalizedCandidate = path.normalize(path.absolute(candidate));
  final normalizedData = path.normalize(path.absolute(dataDirectory));
  return path.equals(normalizedCandidate, normalizedData) ||
      path.isWithin(normalizedData, normalizedCandidate) ||
      path.isWithin(normalizedCandidate, normalizedData);
}

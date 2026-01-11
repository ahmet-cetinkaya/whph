import 'dart:io';
import 'dart:isolate';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:whph/core/application/shared/services/abstraction/i_single_instance_service.dart';
import 'package:whph/core/domain/shared/utils/logger.dart';

class DesktopSingleInstanceService implements ISingleInstanceService {
  static const String _lockFileName = 'whph.lock';
  static const String _ipcFileName = 'whph.ipc';
  static const int _ipcCheckIntervalMs = 500;

  File? _lockFile;
  File? _ipcFile;
  RandomAccessFile? _lockHandle;
  Isolate? _ipcListenerIsolate;
  ReceivePort? _ipcReceivePort;
  SendPort? _ipcListenerSendPort;
  Function(String)? _onCommandReceived;

  @override
  Future<bool> isAnotherInstanceRunning() async {
    try {
      final lockFile = await _getLockFile();

      // Try to open the lock file exclusively
      try {
        final handle = await lockFile.open(mode: FileMode.write);

        // Try to get an exclusive lock
        await handle.lock(FileLock.exclusive);
        await handle.unlock();
        await handle.close();

        // If we got here, no other instance is running
        return false;
      } catch (e) {
        // Lock failed, another instance is running
        return true;
      }
    } catch (e) {
      Logger.error('Error checking for existing instance: $e');
      return false;
    }
  }

  @override
  Future<bool> lockInstance() async {
    try {
      _lockFile = await _getLockFile();

      // Create the lock file if it doesn't exist
      if (!await _lockFile!.exists()) {
        await _lockFile!.create(recursive: true);
      }

      _lockHandle = await _lockFile!.open(mode: FileMode.write);
      await _lockHandle!.lock(FileLock.exclusive);

      // Write current process ID
      await _lockHandle!.writeString(pid.toString());
      await _lockHandle!.flush();

      Logger.info('Single instance lock acquired');
      return true;
    } catch (e) {
      Logger.error('Failed to acquire single instance lock: $e');
      return false;
    }
  }

  @override
  Future<void> releaseInstance() async {
    try {
      if (_lockHandle != null) {
        await _lockHandle!.unlock();
        await _lockHandle!.close();
        _lockHandle = null;
      }

      if (_lockFile != null && await _lockFile!.exists()) {
        await _lockFile!.delete();
        _lockFile = null;
      }

      await stopListeningForCommands();

      Logger.info('Single instance lock released');
    } catch (e) {
      Logger.error('Error releasing single instance lock: $e');
    }
  }

  @override
  Future<bool> sendCommandToExistingInstance(String command) async {
    try {
      final ipcFile = await _getIPCFile();

      // Write command with timestamp and pid
      await ipcFile.writeAsString(
        '${DateTime.now().millisecondsSinceEpoch}\n$pid\n$command',
        mode: FileMode.write,
      );

      Logger.info('Command "$command" sent to existing instance');
      return true;
    } catch (e) {
      Logger.error('Failed to send command: $e');
      return false;
    }
  }

  @override
  Future<void> startListeningForCommands(Function(String) onCommandReceived) async {
    _onCommandReceived = onCommandReceived;

    try {
      // Create IPC file if it doesn't exist
      _ipcFile = await _getIPCFile();
      if (!await _ipcFile!.exists()) {
        await _ipcFile!.create(recursive: true);
      }

      // Start the isolate to monitor IPC requests
      _ipcReceivePort = ReceivePort();
      final commandReceivePort = ReceivePort();

      _ipcListenerIsolate = await Isolate.spawn(
        _ipcListenerIsolateEntry,
        {
          'ipcSendPort': _ipcReceivePort!.sendPort,
          'commandSendPort': commandReceivePort.sendPort,
          'ipcFilePath': _ipcFile!.path,
          'intervalMs': _ipcCheckIntervalMs,
          'currentPid': pid,
        },
      );

      // Get the send port for communicating with the isolate
      _ipcListenerSendPort = await commandReceivePort.first;
      commandReceivePort.close();

      // Listen for commands from the isolate
      _ipcReceivePort!.listen((message) {
        if (message is String && _onCommandReceived != null) {
          _onCommandReceived!(message);
        }
      });

      Logger.info('Started listening for IPC commands');
    } catch (e) {
      Logger.error('Failed to start IPC listener: $e');
    }
  }

  @override
  Future<void> stopListeningForCommands() async {
    try {
      // Signal the isolate to shut down gracefully
      if (_ipcListenerSendPort != null) {
        _ipcListenerSendPort!.send('shutdown');
        _ipcListenerSendPort = null;
      }

      if (_ipcListenerIsolate != null) {
        // Give the isolate a moment to shut down gracefully
        await Future.delayed(Duration(milliseconds: 100));
        _ipcListenerIsolate!.kill();
        _ipcListenerIsolate = null;
      }

      if (_ipcReceivePort != null) {
        _ipcReceivePort!.close();
        _ipcReceivePort = null;
      }

      if (_ipcFile != null && await _ipcFile!.exists()) {
        await _ipcFile!.delete();
        _ipcFile = null;
      }

      Logger.info('Stopped listening for IPC commands');
    } catch (e) {
      Logger.error('Error stopping IPC listener: $e');
    }
  }

  Future<File> _getLockFile() async {
    final tempDir = await getTemporaryDirectory();
    return File(path.join(tempDir.path, _lockFileName));
  }

  Future<File> _getIPCFile() async {
    final tempDir = await getTemporaryDirectory();
    return File(path.join(tempDir.path, _ipcFileName));
  }

  static void _ipcListenerIsolateEntry(Map<String, dynamic> params) async {
    final SendPort ipcSendPort = params['ipcSendPort'];
    final SendPort commandSendPort = params['commandSendPort'];
    final String ipcFilePath = params['ipcFilePath'];
    final int intervalMs = params['intervalMs'];
    final int currentPid = params['currentPid'];

    // Set up command listener
    final commandReceivePort = ReceivePort();
    commandSendPort.send(commandReceivePort.sendPort);

    bool shouldExit = false;
    commandReceivePort.listen((message) {
      if (message == 'shutdown') {
        shouldExit = true;
        commandReceivePort.close();
      }
    });

    final ipcFile = File(ipcFilePath);
    DateTime lastModified = DateTime.fromMillisecondsSinceEpoch(0);

    while (!shouldExit) {
      try {
        await Future.delayed(Duration(milliseconds: intervalMs));

        if (!await ipcFile.exists()) continue;

        final stat = await ipcFile.stat();
        if (stat.modified.isAfter(lastModified)) {
          lastModified = stat.modified;

          final content = await ipcFile.readAsString();
          final lines = content.trim().split('\n');

          if (lines.length >= 2) {
            final requestPid = int.tryParse(lines[1]);
            // Default to FOCUS if no 3rd line
            final command = lines.length >= 3 ? lines[2] : 'FOCUS';

            // Don't respond to our own requests
            if (requestPid != null && requestPid != currentPid) {
              ipcSendPort.send(command);

              // Clear the IPC file after processing
              await ipcFile.writeAsString('', mode: FileMode.write);
            }
          }
        }
      } catch (e, s) {
        debugPrint('Error in IPC listener isolate: $e\n$s');
      }
    }
  }
}

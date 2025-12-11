import 'dart:io';
import 'dart:isolate';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:whph/core/application/shared/services/abstraction/i_single_instance_service.dart';
import 'package:whph/core/domain/shared/utils/logger.dart';

class DesktopSingleInstanceService implements ISingleInstanceService {
  static const String _lockFileName = 'whph.lock';
  static const String _focusFileName = 'whph.focus';
  static const int _focusCheckIntervalMs = 500;

  File? _lockFile;
  File? _focusFile;
  RandomAccessFile? _lockHandle;
  Isolate? _focusListenerIsolate;
  ReceivePort? _focusReceivePort;
  SendPort? _focusListenerSendPort;
  Function()? _onFocusRequested;

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

      await stopListeningForFocusCommands();

      Logger.info('Single instance lock released');
    } catch (e) {
      Logger.error('Error releasing single instance lock: $e');
    }
  }

  @override
  Future<bool> sendFocusToExistingInstance() async {
    try {
      final focusFile = await _getFocusFile();

      // Write focus request with timestamp
      await focusFile.writeAsString(
        '${DateTime.now().millisecondsSinceEpoch}\n$pid',
        mode: FileMode.write,
      );

      Logger.info('Focus request sent to existing instance');
      return true;
    } catch (e) {
      Logger.error('Failed to send focus request: $e');
      return false;
    }
  }

  @override
  Future<void> startListeningForFocusCommands(Function() onFocusRequested) async {
    _onFocusRequested = onFocusRequested;

    try {
      // Create focus file if it doesn't exist
      _focusFile = await _getFocusFile();
      if (!await _focusFile!.exists()) {
        await _focusFile!.create(recursive: true);
      }

      // Start the isolate to monitor focus requests
      _focusReceivePort = ReceivePort();
      final commandReceivePort = ReceivePort();

      _focusListenerIsolate = await Isolate.spawn(
        _focusListenerIsolateEntry,
        {
          'focusSendPort': _focusReceivePort!.sendPort,
          'commandSendPort': commandReceivePort.sendPort,
          'focusFilePath': _focusFile!.path,
          'intervalMs': _focusCheckIntervalMs,
          'currentPid': pid,
        },
      );

      // Get the send port for communicating with the isolate
      _focusListenerSendPort = await commandReceivePort.first;
      commandReceivePort.close();

      // Listen for focus requests from the isolate
      _focusReceivePort!.listen((message) {
        if (message == 'focus_requested' && _onFocusRequested != null) {
          _onFocusRequested!();
        }
      });

      Logger.info('Started listening for focus commands');
    } catch (e) {
      Logger.error('Failed to start focus listener: $e');
    }
  }

  @override
  Future<void> stopListeningForFocusCommands() async {
    try {
      // Signal the isolate to shut down gracefully
      if (_focusListenerSendPort != null) {
        _focusListenerSendPort!.send('shutdown');
        _focusListenerSendPort = null;
      }

      if (_focusListenerIsolate != null) {
        // Give the isolate a moment to shut down gracefully
        await Future.delayed(Duration(milliseconds: 100));
        _focusListenerIsolate!.kill();
        _focusListenerIsolate = null;
      }

      if (_focusReceivePort != null) {
        _focusReceivePort!.close();
        _focusReceivePort = null;
      }

      if (_focusFile != null && await _focusFile!.exists()) {
        await _focusFile!.delete();
        _focusFile = null;
      }

      Logger.info('Stopped listening for focus commands');
    } catch (e) {
      Logger.error('Error stopping focus listener: $e');
    }
  }

  Future<File> _getLockFile() async {
    final tempDir = await getTemporaryDirectory();
    return File(path.join(tempDir.path, _lockFileName));
  }

  Future<File> _getFocusFile() async {
    final tempDir = await getTemporaryDirectory();
    return File(path.join(tempDir.path, _focusFileName));
  }

  static void _focusListenerIsolateEntry(Map<String, dynamic> params) async {
    final SendPort focusSendPort = params['focusSendPort'];
    final SendPort commandSendPort = params['commandSendPort'];
    final String focusFilePath = params['focusFilePath'];
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

    final focusFile = File(focusFilePath);
    DateTime lastModified = DateTime.fromMillisecondsSinceEpoch(0);

    while (!shouldExit) {
      try {
        await Future.delayed(Duration(milliseconds: intervalMs));

        if (!await focusFile.exists()) continue;

        final stat = await focusFile.stat();
        if (stat.modified.isAfter(lastModified)) {
          lastModified = stat.modified;

          final content = await focusFile.readAsString();
          final lines = content.trim().split('\n');

          if (lines.length >= 2) {
            final requestPid = int.tryParse(lines[1]);

            // Don't respond to our own requests
            if (requestPid != null && requestPid != currentPid) {
              focusSendPort.send('focus_requested');

              // Clear the focus file after processing
              await focusFile.writeAsString('', mode: FileMode.write);
            }
          }
        }
      } catch (e, s) {
        // Log errors in the isolate to aid debugging, instead of swallowing them.
        // Use print instead of Logger since this is in an isolate
        // Use debugPrint for consistent logging in isolates
        debugPrint('Error in focus listener isolate: $e\n$s');
      }
    }
  }
}

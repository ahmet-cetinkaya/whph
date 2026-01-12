import 'dart:async';
import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:whph/core/application/shared/services/abstraction/i_single_instance_service.dart';
import 'package:whph/core/domain/shared/utils/logger.dart';

class DesktopSingleInstanceService implements ISingleInstanceService {
  static const String _lockFileName = 'whph.lock';
  static const String _portFileName = 'whph.port';

  File? _lockFile;
  RandomAccessFile? _lockHandle;
  ServerSocket? _serverSocket;
  final List<Socket> _connectedClients = [];
  Function(String)? _onCommandReceived;

  @override
  Future<bool> isAnotherInstanceRunning() async {
    try {
      final portFile = await _getPortFile();
      final lockFile = await _getLockFile();

      if (!await portFile.exists()) {
        // If port file missing but lock file exists, another instance is starting or assumed running
        if (await lockFile.exists()) {
          Logger.debug('Lock file exists but port file missing. Instance might be starting.');
          // Give it a small moment to write the port file? Or just assume it's running.
          // Safety: return true to let lockInstance handle the final arbitrating if it's dead.
          return true;
        }
        Logger.debug('Port and lock files not found, assuming no instance running');
        return false;
      }

      final portContent = await portFile.readAsString();
      final port = int.tryParse(portContent);
      if (port == null) {
        Logger.warning('Invalid port file content');
        // If content invalid but lock exists, assume running/bad state.
        if (await lockFile.exists()) return true;
        return false;
      }

      // Try to connect to the existing instance
      try {
        final socket =
            await Socket.connect(InternetAddress.loopbackIPv4, port, timeout: const Duration(milliseconds: 500));
        socket.destroy();
        return true;
      } catch (e) {
        Logger.debug('Failed to connect to existing port, instance likely dead: $e');
        // If connection failed, but lock exists, it might be zombie or hung.
        // If we return false, we proceed to try to take lock.
        return false;
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
      final portFile = await _getPortFile();
      if (!await portFile.exists()) return false;

      final port = int.parse(await portFile.readAsString());
      final socket = await Socket.connect(InternetAddress.loopbackIPv4, port);

      socket.write('$command\n');
      await socket.flush();
      socket.destroy();

      Logger.info('Command "$command" sent to existing instance');
      return true;
    } catch (e) {
      Logger.error('Failed to send command: $e');
      return false;
    }
  }

  @override
  Future<void> sendCommandAndStreamOutput(String command, {required Function(String) onOutput}) async {
    try {
      final portFile = await _getPortFile();
      if (!await portFile.exists()) {
        onOutput('Error: No running instance found.');
        return;
      }

      final portContent = await portFile.readAsString();
      final port = int.tryParse(portContent);
      if (port == null) {
        onOutput('Error: Invalid port file content.');
        return;
      }

      final socket = await Socket.connect(InternetAddress.loopbackIPv4, port);

      // Send command
      socket.write('$command\n');
      await socket.flush();

      // Listen for updates
      final Completer<void> completer = Completer<void>();
      String buffer = '';

      socket.listen(
        (data) {
          buffer += String.fromCharCodes(data);

          int newlineIndex;
          while ((newlineIndex = buffer.indexOf('\n')) != -1) {
            final line = buffer.substring(0, newlineIndex).trim();
            buffer = buffer.substring(newlineIndex + 1);

            if (line == 'DONE') {
              socket.destroy();
              if (!completer.isCompleted) completer.complete();
              return;
            } else if (line.isNotEmpty) {
              onOutput(line);
            }
          }
        },
        onError: (error) {
          onOutput('Error: Connection error $error');
          if (!completer.isCompleted) completer.complete();
        },
        onDone: () {
          if (!completer.isCompleted) completer.complete();
        },
      );

      await completer.future;
    } catch (e) {
      onOutput('Failed to send command: $e');
    }
  }

  @override
  Future<void> startListeningForCommands(Function(String) onCommandReceived) async {
    _onCommandReceived = onCommandReceived;

    try {
      // Bind to any available port on loopback
      _serverSocket = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);

      // Write port to file
      final portFile = await _getPortFile();
      await portFile.writeAsString(_serverSocket!.port.toString());

      Logger.info('Listening for IPC commands on port ${_serverSocket!.port}');

      _serverSocket!.listen((socket) {
        _connectedClients.add(socket);

        String buffer = '';

        socket.listen(
          (data) {
            buffer += String.fromCharCodes(data);

            int newlineIndex;
            while ((newlineIndex = buffer.indexOf('\n')) != -1) {
              final message = buffer.substring(0, newlineIndex).trim();
              buffer = buffer.substring(newlineIndex + 1);

              Logger.debug('Received IPC message: $message');
              if (_onCommandReceived != null && message.isNotEmpty) {
                _onCommandReceived!(message);
              }

              // If it's just a focus command, we can close connection immediately
              if (message == 'FOCUS') {
                socket.destroy();
                _connectedClients.remove(socket);
              }
            }
          },
          onError: (error) {
            Logger.error('IPC Client error: $error');
            _connectedClients.remove(socket);
            socket.destroy();
          },
          onDone: () {
            _connectedClients.remove(socket);
          },
        );
      });
    } catch (e) {
      Logger.error('Failed to start IPC listener: $e');
    }
  }

  @override
  Future<void> stopListeningForCommands() async {
    try {
      final clients = List<Socket>.from(_connectedClients);
      for (final client in clients) {
        client.destroy();
      }
      _connectedClients.clear();

      await _serverSocket?.close();
      _serverSocket = null;

      final portFile = await _getPortFile();
      if (await portFile.exists()) {
        await portFile.delete();
      }

      Logger.info('Stopped listening for IPC commands');
    } catch (e) {
      Logger.error('Error stopping IPC listener: $e');
    }
  }

  @override
  void broadcastMessage(String message) {
    if (_connectedClients.isEmpty) return;

    final data = '$message\n';
    // Create a copy list to iterate safely
    final clients = List<Socket>.from(_connectedClients);

    for (final client in clients) {
      try {
        client.write(data);
      } catch (e) {
        Logger.debug('Failed to write to client: $e');
        _connectedClients.remove(client);
      }
    }
  }

  Future<File> _getLockFile() async {
    final tempDir = await getTemporaryDirectory();
    return File(path.join(tempDir.path, _lockFileName));
  }

  Future<File> _getPortFile() async {
    final tempDir = await getTemporaryDirectory();
    return File(path.join(tempDir.path, _portFileName));
  }
}

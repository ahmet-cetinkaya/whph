import 'dart:async';
import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:application/shared/services/abstraction/i_single_instance_service.dart';
import 'package:domain/shared/utils/logger.dart';

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
        // If port file missing but lock file exists, another instance might be starting or it might be a stale lock.
        if (await lockFile.exists()) {
          DomainLogger.debug('Lock file exists but port file missing. Checking if instance is starting...');

          // Wait for a short moment to see if the port file appears (handling instances that are currently starting)
          for (int i = 0; i < 5; i++) {
            await Future.delayed(const Duration(milliseconds: 100));
            if (await portFile.exists()) {
              DomainLogger.debug('Port file appeared after waiting, another instance is starting.');
              return true;
            }
          }

          DomainLogger.debug('Port file did not appear after waiting. Assuming lock is stale.');
          return false;
        }
        DomainLogger.debug('Port and lock files not found, assuming no instance running');
        return false;
      }

      final portContent = await portFile.readAsString();
      final port = int.tryParse(portContent);
      if (port == null) {
        DomainLogger.warning('Invalid port file content');
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
        DomainLogger.debug('Failed to connect to existing port, instance likely dead: $e');
        // If connection failed, but lock exists, it might be zombie or hung.
        // If we return false, we proceed to try to take lock.
        return false;
      }
    } catch (e) {
      DomainLogger.error('Error checking for existing instance: $e');
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

      DomainLogger.info('Single instance lock acquired');
      return true;
    } catch (e) {
      DomainLogger.error('Failed to acquire single instance lock: $e');
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

      DomainLogger.info('Single instance lock released');
    } catch (e) {
      DomainLogger.error('Error releasing single instance lock: $e');
    }
  }

  @override
  Future<bool> sendCommandToExistingInstance(String command) async {
    Socket? socket;
    try {
      final portFile = await _getPortFile();
      if (!await portFile.exists()) return false;

      final portContent = await portFile.readAsString();
      final port = int.tryParse(portContent);
      if (port == null) {
        DomainLogger.error('Invalid port file content');
        return false;
      }
      socket = await Socket.connect(
        InternetAddress.loopbackIPv4,
        port,
        timeout: const Duration(milliseconds: 500),
      );

      socket.write('$command\n');
      await socket.flush();
      socket.destroy();

      DomainLogger.info('Command "$command" sent to existing instance');
      return true;
    } on SocketException catch (e) {
      DomainLogger.error('Socket error sending command: $e');
      return false;
    } on TimeoutException catch (e) {
      DomainLogger.error('Timeout sending command: $e');
      return false;
    } catch (e) {
      DomainLogger.error('Failed to send command: $e');
      return false;
    } finally {
      socket?.destroy();
    }
  }

  @override
  Future<void> sendCommandAndStreamOutput(String command, {required Function(String) onOutput}) async {
    Socket? socket;
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

      socket = await Socket.connect(
        InternetAddress.loopbackIPv4,
        port,
        timeout: const Duration(milliseconds: 500),
      );

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
              socket?.destroy();
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
    } on SocketException catch (e) {
      onOutput('Error: Could not connect to running instance. Is WHPH running?');
      DomainLogger.error('Socket error in sendCommandAndStreamOutput: $e');
    } on TimeoutException catch (e) {
      onOutput('Error: Connection timed out. The instance may be busy.');
      DomainLogger.error('Timeout in sendCommandAndStreamOutput: $e');
    } catch (e) {
      onOutput('Failed to send command: $e');
      DomainLogger.error('Unexpected error in sendCommandAndStreamOutput: $e');
    } finally {
      socket?.destroy();
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

      DomainLogger.info('Listening for IPC commands on port ${_serverSocket!.port}');

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

              DomainLogger.debug('Received IPC message: $message');
              if (_onCommandReceived != null && message.isNotEmpty) {
                _onCommandReceived!(message);
              }

              // If it's just a focus command, we can close connection immediately
              if (message == 'FOCUS') {
                socket.destroy();
              }
            }
          },
          onError: (error) {
            DomainLogger.error('IPC Client error: $error');
            _connectedClients.remove(socket);
            socket.destroy();
          },
          onDone: () {
            _connectedClients.remove(socket);
          },
        );
      });
    } catch (e) {
      DomainLogger.error('Failed to start IPC listener: $e');
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

      DomainLogger.info('Stopped listening for IPC commands');
    } catch (e) {
      DomainLogger.error('Error stopping IPC listener: $e');
    }
  }

  @override
  Future<bool> broadcastMessage(String message) async {
    if (_connectedClients.isEmpty) {
      DomainLogger.warning('Attempted to broadcast but no clients connected');
      return false;
    }

    final data = '$message\n';
    // Create a copy list to iterate safely
    final clients = List<Socket>.from(_connectedClients);
    bool success = false;

    for (final client in clients) {
      try {
        client.write(data);
        await client.flush();
        success = true;
      } catch (e) {
        DomainLogger.error('Failed to write to client: $e');
        _connectedClients.remove(client);
        client.destroy();
      }
    }

    if (!success) {
      DomainLogger.error('Failed to broadcast message to any client: $message');
    }

    return success;
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

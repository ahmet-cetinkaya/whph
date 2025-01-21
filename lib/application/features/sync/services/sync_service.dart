import 'dart:async';
import 'dart:convert';
import 'package:dart_json_mapper/dart_json_mapper.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/application/features/sync/commands/sync_command.dart';
import 'package:whph/application/features/sync/queries/get_list_syncs_query.dart';
import 'package:whph/application/shared/models/websocket_request.dart';
import 'package:whph/presentation/shared/utils/network_utils.dart';

import 'abstraction/i_sync_service.dart';

class SyncService implements ISyncService {
  final Mediator _mediator;
  final _syncCompleteController = StreamController<bool>.broadcast();
  Timer? _periodicTimer;
  WebSocketChannel? _channel;
  DateTime? _lastSyncTime;
  bool _isConnected = false;
  Timer? _reconnectTimer;
  static const Duration _syncInterval = Duration(minutes: 1);
  static const Duration _reconnectDelay = Duration(seconds: 5);
  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 3;
  bool _isInitializing = false;

  Stream<bool> get onSyncComplete => _syncCompleteController.stream;
  bool get isConnected => _isConnected;

  SyncService(this._mediator) {
    _initializeWebSocket();
  }

  Future<void> _initializeWebSocket() async {
    // Eğer zaten bağlıysak veya başlatma işlemi devam ediyorsa çık
    if (_isConnected || _isInitializing || _reconnectAttempts >= _maxReconnectAttempts) return;

    _isInitializing = true;

    try {
      // Bağlanılacak IP'yi almak için mevcut sync device'ları kontrol et
      var syncDevices = await _mediator.send<GetListSyncDevicesQuery, GetListSyncDevicesQueryResponse>(
          GetListSyncDevicesQuery(pageIndex: 0, pageSize: 10));
      var targetIp = syncDevices.items.isNotEmpty ? syncDevices.items.first.fromIp : null;

      if (targetIp != null) {
        print('DEBUG: Attempting to connect to WebSocket at ws://$targetIp:4040 (Attempt ${_reconnectAttempts + 1})');

        bool canConnect = await NetworkUtils.testWebSocketConnection(
          targetIp,
          timeout: const Duration(seconds: 5),
        );

        if (!canConnect) {
          print('DEBUG: No WebSocket server available at ws://$targetIp:4040');
          _handleDisconnection();
          return;
        }

        _channel?.sink.close();
        _channel = WebSocketChannel.connect(Uri.parse('ws://$targetIp:4040'));

        _channel!.stream.listen(
          (message) {
            _isConnected = true;
            _reconnectAttempts = 0;
            _handleWebSocketMessage(message);
          },
          onError: (error) {
            print('ERROR: WebSocket error: $error');
            _handleDisconnection();
          },
          onDone: () {
            print('DEBUG: WebSocket connection closed');
            _handleDisconnection();
          },
          cancelOnError: false,
        );

        _isConnected = true;
        _reconnectAttempts = 0; // Başarılı bağlantıda deneme sayısını sıfırla
        print('DEBUG: WebSocket connected successfully');
      } else {
        print('DEBUG: No sync devices found to connect to');
        return;
      }
    } catch (e) {
      print('ERROR: WebSocket connection error: $e');
      _handleDisconnection();
    } finally {
      _isInitializing = false;
    }
  }

  void _handleDisconnection() {
    _isConnected = false;
    _channel?.sink.close();
    _channel = null;

    // Force close durumunda yeniden bağlanmaya çalışma
    if (_lastSyncTime != null && DateTime.now().difference(_lastSyncTime!) < const Duration(seconds: 5)) {
      print('DEBUG: Recent sync completed, skipping reconnection');
      return;
    }

    // Eğer maksimum deneme sayısına ulaştıysak veya başlatma işlemi devam ediyorsa
    if (_reconnectAttempts >= _maxReconnectAttempts || _isInitializing) {
      print('DEBUG: Max reconnection attempts reached or initialization in progress, resetting counter');
      _reconnectAttempts = 0;
      return;
    }

    // Normal disconnect durumunda yeniden bağlanmayı dene
    _reconnectAttempts++;
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(_reconnectDelay * _reconnectAttempts, _initializeWebSocket);
  }

  void _handleWebSocketMessage(dynamic message) {
    try {
      print('DEBUG: Processing WebSocket message');
      final data = jsonDecode(message);

      switch (data['type']) {
        case 'sync':
          print('DEBUG: Received sync data message');
          _processSyncData(data['data']);

          if (_channel != null && _isConnected) {
            print('DEBUG: Sending sync_complete response');
            _channel!.sink.add(JsonMapper.serialize(WebSocketMessage(
                type: 'sync_complete', data: {'success': true, 'timestamp': DateTime.now().toIso8601String()})));
          }
          break;

        case 'sync_complete':
          print('DEBUG: Received sync_complete message');
          if (data['data']?['success'] == true) {
            print('DEBUG: Processing sync complete');
            _processSyncComplete(data['data']);
          }
          break;

        default:
          print('WARNING: Unknown message type: ${data['type']}');
          break;
      }
    } catch (e, stack) {
      print('ERROR: Failed to process WebSocket message: $e');
      print('Stack trace: $stack');
      _forceCloseConnection();
    }
  }

  void _forceCloseConnection() {
    print('DEBUG: Force closing WebSocket connection');
    if (_isConnected) {
      // Mark last sync time before closing
      _lastSyncTime = DateTime.now();

      // Send a close frame before closing
      _channel?.sink.add(
          JsonMapper.serialize(WebSocketMessage(type: 'close', data: {'timestamp': DateTime.now().toIso8601String()})));

      // Close immediately
      _channel?.sink.close();
      _channel = null;
      _isConnected = false;

      // Notify sync completion
      notifySyncComplete();
    }
  }

  void _processSyncData(Map<String, dynamic> data) {
    try {
      if (data['syncDevice']?['lastSyncDate'] != null) {
        // Update last sync time but don't notify completion yet
        _lastSyncTime = DateTime.parse(data['syncDevice']['lastSyncDate']);
        print('DEBUG: Updated last sync time to: $_lastSyncTime');
      }
    } catch (e) {
      print('ERROR: Failed to process sync data: $e');
    }
  }

  void _processSyncComplete(Map<String, dynamic> data) {
    try {
      if (data['syncDataDto']?['syncDevice']?['lastSyncDate'] != null) {
        _lastSyncTime = DateTime.parse(data['syncDataDto']['syncDevice']['lastSyncDate']);
      } else {
        _lastSyncTime = DateTime.now();
      }

      print('DEBUG: Sync completed at: $_lastSyncTime');
      _scheduleNextSync();
    } catch (e) {
      print('ERROR: Failed to process sync complete: $e');
    }
  }

  @override
  Future<void> startSync() async {
    // Önce mevcut timer'ı temizle
    stopSync();

    // İlk sync'i çalıştır
    await runSync();

    // Periyodik sync'i başlat
    _periodicTimer = Timer.periodic(_syncInterval, (timer) async {
      try {
        print('DEBUG: Running periodic sync at ${DateTime.now()}');
        await runSync();
      } catch (e) {
        print('ERROR: Periodic sync failed: $e');
      }
    });

    print('DEBUG: Started periodic sync with interval: ${_syncInterval.inMinutes} minutes');
  }

  @override
  Future<void> runSync() async {
    try {
      if (!_isConnected) {
        print('DEBUG: Attempting to reconnect before sync...');
        await _initializeWebSocket();

        if (!_isConnected) {
          print('DEBUG: Could not establish WebSocket connection, skipping sync');
          return;
        }
      }

      print('DEBUG: Starting sync process at ${DateTime.now()}...');
      await _mediator.send(SyncCommand());

      // Sync başarılı olduysa bağlantı denemelerini sıfırla
      _reconnectAttempts = 0;

      // Başarılı bir sync sonrası yeterli süre bekle ve bağlantıyı kapat
      Timer(const Duration(seconds: 1), () {
        if (_isConnected) {
          print('DEBUG: Sync completed, closing connection');
          _forceCloseConnection();
        }
      });
    } catch (e) {
      print('ERROR: Sync failed: $e');
      _handleDisconnection();
    }
  }

  @override
  void stopSync() {
    if (_periodicTimer != null) {
      print('DEBUG: Stopping periodic sync');
      _periodicTimer!.cancel();
      _periodicTimer = null;
    }
  }

  void _scheduleNextSync() {
    // Bu metodu basitleştirelim, sadece son sync zamanını güncellesin
    if (_lastSyncTime != null) {
      print('DEBUG: Last sync time updated to: $_lastSyncTime');
    }
  }

  void notifySyncComplete() {
    print('DEBUG: Notifying sync completion at ${DateTime.now()}');
    _syncCompleteController.add(true);
  }

  @override
  void dispose() {
    stopSync();
    _channel?.sink.close();
    _syncCompleteController.close();
  }
}

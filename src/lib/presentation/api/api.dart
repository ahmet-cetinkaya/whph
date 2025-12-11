import 'dart:io';
import 'dart:async';
import 'package:dart_json_mapper/dart_json_mapper.dart';
import 'package:whph/core/application/features/sync/commands/paginated_sync_command.dart';
import 'package:whph/core/application/shared/models/websocket_request.dart';
import 'package:whph/core/application/features/sync/models/paginated_sync_data_dto.dart';
import 'package:whph/core/application/features/sync/services/abstraction/i_sync_service.dart';
import 'package:whph/core/application/features/sync/models/sync_status.dart';
import 'package:whph/core/domain/shared/utils/logger.dart';
import 'package:whph/main.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/core/application/features/sync/queries/get_sync_query.dart';
import 'package:whph/core/application/features/sync/commands/save_sync_command.dart';
import 'package:whph/core/application/features/sync/services/abstraction/i_device_id_service.dart';
import 'package:whph/presentation/ui/shared/utils/device_info_helper.dart';

const int webSocketPort = 44040;

// Web socket server events
final streamController = StreamController<Map<String, dynamic>>.broadcast();
Stream<Map<String, dynamic>> get serverEvents => streamController.stream;

void startWebSocketServer() async {
  try {
    Logger.info('Attempting to start WebSocket server on port $webSocketPort...');

    final server = await HttpServer.bind(
      InternetAddress.anyIPv4,
      webSocketPort,
      shared: true,
    );

    Logger.info('WebSocket Server successfully started on port $webSocketPort');
    Logger.info('WebSocket Server listening on all IPv4 interfaces (0.0.0.0:$webSocketPort)');
    Logger.info('Ready to receive sync requests from other devices');

    // Handle incoming connections
    await for (HttpRequest req in server) {
      try {
        if (req.headers.value('upgrade')?.toLowerCase() == 'websocket') {
          final ws = await WebSocketTransformer.upgrade(req);
          Logger.info(
              'WebSocket connection established from ${req.connectionInfo?.remoteAddress}:${req.connectionInfo?.remotePort}');

          ws.listen(
            (data) async {
              Logger.debug('Received message: $data');
              await _handleWebSocketMessage(data.toString(), ws);
            },
            onError: (e) {
              Logger.error('Connection error: $e');
              ws.close();
            },
            onDone: () {
              Logger.debug('Connection closed normally');
            },
            cancelOnError: true,
          );
        } else {
          req.response
            ..statusCode = HttpStatus.upgradeRequired
            ..headers.add('Upgrade', 'websocket')
            ..headers.add('Connection', 'Upgrade')
            ..write('WebSocket upgrade required')
            ..close();
        }
      } catch (e) {
        Logger.error('Request handling error: $e');
        req.response.statusCode = HttpStatus.internalServerError;
        await req.response.close();
      }
    }
  } catch (e) {
    Logger.error('💥 WebSocket server failed to start on port $webSocketPort: $e');
    rethrow;
  }
}

Future<void> _handleWebSocketMessage(String message, WebSocket socket) async {
  ISyncService? syncService;

  try {
    Logger.debug('Received message: $message');

    WebSocketMessage? parsedMessage = JsonMapper.deserialize<WebSocketMessage>(message);
    if (parsedMessage == null) {
      throw FormatException('Error parsing WebSocket message');
    }

    switch (parsedMessage.type) {
      case 'test':
        // Send test response
        socket.add(JsonMapper.serialize(WebSocketMessage(
          type: 'test_response',
          data: {
            'success': true,
            'timestamp': DateTime.now().toIso8601String(),
          },
        )));
        break;

      case 'device_info':
        // Send device information for handshake
        Logger.info('Processing device info request...');
        try {
          final deviceIdService = container.resolve<IDeviceIdService>();
          final deviceId = await deviceIdService.getDeviceId();
          final deviceName = await DeviceInfoHelper.getDeviceName();

          socket.add(JsonMapper.serialize(WebSocketMessage(
            type: 'device_info_response',
            data: {
              'success': true,
              'deviceId': deviceId,
              'deviceName': deviceName,
              'appName': 'WHPH',
              'platform': Platform.isAndroid
                  ? 'android'
                  : Platform.isIOS
                      ? 'ios'
                      : Platform.isLinux
                          ? 'linux'
                          : Platform.isWindows
                              ? 'windows'
                              : Platform.isMacOS
                                  ? 'macos'
                                  : 'unknown',
              'timestamp': DateTime.now().toIso8601String(),
            },
          )));
        } catch (e) {
          Logger.error('Failed to get device info: $e');
          socket.add(JsonMapper.serialize(WebSocketMessage(
            type: 'device_info_response',
            data: {
              'success': false,
              'error': e.toString(),
              'timestamp': DateTime.now().toIso8601String(),
            },
          )));
        }
        break;

      case 'connection_test':
        // Send connection test response
        socket.add(JsonMapper.serialize(WebSocketMessage(
          type: 'connection_test_response',
          data: {
            'success': true,
            'timestamp': DateTime.now().toIso8601String(),
          },
        )));
        break;

      case 'paginated_sync':
        Logger.info('Processing paginated sync request...');

        // Notify sync service that sync has started (for UI feedback)
        try {
          syncService = container.resolve<ISyncService>();
          syncService.updateSyncStatus(SyncStatus(
            state: SyncState.syncing,
            isManual: false, // Server-side sync is typically not manually initiated
            lastSyncTime: DateTime.now(),
          ));
        } catch (e) {
          Logger.debug('Could not update sync status (server may not have sync service): $e');
        }

        final paginatedSyncData = parsedMessage.data;
        if (paginatedSyncData == null) {
          throw FormatException('Paginated sync message missing data');
        }

        Logger.debug(
            'Paginated sync data received for entity: ${(paginatedSyncData as Map<String, dynamic>)['entityType']}');

        try {
          final mediator = container.resolve<Mediator>();
          final command = PaginatedSyncCommand(paginatedSyncDataDto: PaginatedSyncDataDto.fromJson(paginatedSyncData));
          final response = await mediator.send<PaginatedSyncCommand, PaginatedSyncCommandResponse>(command);
          Logger.info('Paginated sync processing completed successfully');

          // Update lastSyncDate for the sync device on server-side completion
          try {
            await _updateServerSideLastSyncDate(paginatedSyncData);
          } catch (e) {
            Logger.debug('Could not update server-side lastSyncDate: $e');
          }

          WebSocketMessage responseMessage = WebSocketMessage(type: 'paginated_sync_complete', data: {
            'paginatedSyncDataDto': response.paginatedSyncDataDto?.toJson(),
            'success': true,
            'isComplete': response.isComplete,
            'timestamp': DateTime.now().toIso8601String()
          });
          socket.add(JsonMapper.serialize(responseMessage));
          Logger.info('Paginated sync response sent to client');

          // CRITICAL FIX: Add proper delay to ensure response is fully transmitted before close
          await Future.delayed(const Duration(milliseconds: 1000));
          await socket.close();

          // Notify sync service that sync completed successfully - go directly to idle after socket close
          if (syncService != null) {
            try {
              // Wait a bit more to ensure socket is fully closed, then reset to idle
              Timer(const Duration(seconds: 1), () {
                syncService!.updateSyncStatus(SyncStatus(
                  state: SyncState.idle,
                  lastSyncTime: DateTime.now(),
                ));
              });
            } catch (e) {
              Logger.debug('Could not update sync status on completion: $e');
            }
          }
        } catch (e, stackTrace) {
          Logger.error('Paginated sync processing failed: $e');
          Logger.error('Stack trace: $stackTrace');

          // Enhanced error response with debugging information (excluding stack trace for security)
          final errorData = <String, dynamic>{
            'success': false,
            'message': e.toString(),
            'type': e.runtimeType.toString(),
            'timestamp': DateTime.now().toIso8601String(),
            'entityType': (parsedMessage.data as Map<String, dynamic>?)?.containsKey('entityType') == true
                ? (parsedMessage.data as Map<String, dynamic>)['entityType']
                : 'unknown',
            'metadata': <String, dynamic>{},
          };

          // Add specific error details based on error type
          if (e is FormatException) {
            errorData['metadata']['errorCategory'] = 'JSON_PARSING';
            errorData['metadata']['source'] = e.source;
            errorData['metadata']['offset'] = e.offset;
          } else if (e is ArgumentError) {
            errorData['metadata']['errorCategory'] = 'ARGUMENT_ERROR';
            errorData['metadata']['invalidValue'] = e.invalidValue?.toString();
            errorData['metadata']['name'] = e.name;
          } else if (e is StateError) {
            errorData['metadata']['errorCategory'] = 'STATE_ERROR';
          } else if (e.toString().contains('Unable to instantiate')) {
            errorData['metadata']['errorCategory'] = 'ENTITY_INSTANTIATION';
            // Try to extract entity name and missing arguments
            final instantiationMatch = RegExp(r"Unable to instantiate class '(\w+)'").firstMatch(e.toString());
            if (instantiationMatch != null) {
              errorData['metadata']['failedEntityClass'] = instantiationMatch.group(1);
            }
            final argumentsMatch = RegExp(r'with null named arguments \[(.*?)\]').firstMatch(e.toString());
            if (argumentsMatch != null) {
              errorData['metadata']['missingArguments'] = argumentsMatch.group(1)?.split(', ');
            }
          } else {
            errorData['metadata']['errorCategory'] = 'UNKNOWN';
          }

          // Try to capture the problematic entity data if available
          try {
            final paginatedSyncData = parsedMessage.data;
            if (paginatedSyncData is Map<String, dynamic>) {
              errorData['metadata']['pageIndex'] = paginatedSyncData['pageIndex'];
              errorData['metadata']['pageSize'] = paginatedSyncData['pageSize'];
              errorData['metadata']['totalItems'] = paginatedSyncData['totalItems'];

              // Try to identify the first problematic entity
              final entityTypeKey = '${paginatedSyncData['entityType']}sSyncData';
              final syncDataMap = paginatedSyncData[entityTypeKey] as Map<String, dynamic>?;
              if (syncDataMap?['data'] is Map<String, dynamic>) {
                final dataMap = syncDataMap!['data'] as Map<String, dynamic>;
                for (final listKey in ['createSync', 'updateSync', 'deleteSync']) {
                  final entityList = dataMap[listKey] as List?;
                  if (entityList != null && entityList.isNotEmpty) {
                    errorData['metadata']['sampleEntityData'] = entityList.first;
                    break;
                  }
                }
              }
            }
          } catch (metadataError) {
            errorData['metadata']['metadataExtractionError'] = metadataError.toString();
          }

          WebSocketMessage errorMessage = WebSocketMessage(type: 'paginated_sync_error', data: errorData);
          socket.add(JsonMapper.serialize(errorMessage));
          // Close the socket after sending an error to clean up resources
          await socket.close();

          // Notify sync service that sync failed - go directly to idle after socket close
          if (syncService != null) {
            try {
              // Wait a bit more to ensure socket is fully closed, then reset to idle
              Timer(const Duration(seconds: 2), () {
                syncService!.updateSyncStatus(SyncStatus(
                  state: SyncState.idle,
                  lastSyncTime: DateTime.now(),
                ));
              });
            } catch (statusUpdateError) {
              Logger.debug('Could not update sync status on error: $statusUpdateError');
            }
          }
        }
        break;

      default:
        socket.add(JsonMapper.serialize(WebSocketMessage(type: 'error', data: {'message': 'Unknown message type'})));
        await socket.close();
        break;
    }
  } catch (e) {
    Logger.error('Error processing WebSocket message: $e');
    socket.add(JsonMapper.serialize(WebSocketMessage(type: 'error', data: {'message': e.toString()})));
    await socket.close();

    // Reset sync status to idle on any error
    if (syncService != null) {
      try {
        Timer(const Duration(seconds: 1), () {
          syncService!.updateSyncStatus(SyncStatus(
            state: SyncState.idle,
            lastSyncTime: DateTime.now(),
          ));
        });
      } catch (e) {
        Logger.debug('Could not reset sync status on error: $e');
      }
    }
    rethrow;
  }
}

/// Updates lastSyncDate for the sync device on server-side after successful sync
Future<void> _updateServerSideLastSyncDate(Map<String, dynamic> paginatedSyncData) async {
  try {
    // Extract syncDevice from client data to get the same lastSyncDate
    final syncDeviceData = paginatedSyncData['syncDevice'] as Map<String, dynamic>?;
    if (syncDeviceData == null) {
      Logger.debug('Cannot update lastSyncDate: missing syncDevice information');
      return;
    }

    final clientLastSyncDate = syncDeviceData['lastSyncDate'] as String?;
    if (clientLastSyncDate == null) {
      Logger.debug('Cannot update lastSyncDate: missing lastSyncDate from client');
      return;
    }

    // Parse the timestamp from client
    final DateTime clientSyncTimestamp = DateTime.parse(clientLastSyncDate);

    final mediator = container.resolve<Mediator>();

    // Find the sync device by IP pair
    final clientIp = syncDeviceData['fromIp'] as String?;
    final serverIp = syncDeviceData['toIp'] as String?;

    if (clientIp == null || serverIp == null) {
      Logger.debug('Cannot update lastSyncDate: missing IP information in syncDevice');
      return;
    }

    final getSyncQuery = GetSyncDeviceQuery(
      fromIP: clientIp,
      toIP: serverIp,
      fromDeviceId: syncDeviceData['fromDeviceId'] as String? ?? '',
      toDeviceId: syncDeviceData['toDeviceId'] as String? ?? '',
    );
    final syncResponse = await mediator.send<GetSyncDeviceQuery, GetSyncDeviceQueryResponse?>(getSyncQuery);

    if (syncResponse != null) {
      // Use the SAME timestamp from client to ensure consistency
      final updateCommand = SaveSyncDeviceCommand(
        id: syncResponse.id,
        name: syncResponse.name,
        fromIP: syncResponse.fromIp,
        toIP: syncResponse.toIp,
        fromDeviceId: syncResponse.fromDeviceId,
        toDeviceId: syncResponse.toDeviceId,
        lastSyncDate: clientSyncTimestamp, // Use client's timestamp!
      );

      await mediator.send<SaveSyncDeviceCommand, SaveSyncDeviceCommandResponse>(updateCommand);
      Logger.debug('Server-side lastSyncDate updated with client timestamp: $clientSyncTimestamp');
    } else {
      Logger.debug('Sync device not found for IP pair: $clientIp -> $serverIp');
    }
  } catch (e) {
    Logger.error('Failed to update server-side lastSyncDate: $e');
  }
}

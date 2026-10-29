import 'package:whph/core/application/features/sync/models/sync_pairing_models.dart';

/// TCP port of the LAN sync server. The server itself lives in
/// `infrastructure/shared/features/sync/lan_sync_server.dart`; this file no
/// longer binds the port.
const int webSocketPort = syncLanPort;

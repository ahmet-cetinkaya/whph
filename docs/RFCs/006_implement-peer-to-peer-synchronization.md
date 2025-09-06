# Implement Peer-to-Peer Synchronization

## RFC Number

006

## Status

Implemented

## Authors

Development Team

## Summary

This RFC defines the sync module for WHPH, enabling P2P data synchronization across devices in core/application/features/sync/ for services/queries. It supports QR pairing, conflict resolution, selective sync, and offline queuing using Flutter plugins and Drift, ensuring privacy-focused portability without cloud, adapted from PRD for local-first over MODULES.md's Firebase suggestion.

## Motivation

Multi-device access requires seamless sync (PRD 2.3, 4.4), but cloud contradicts privacy (1.3, 5.1.3). P2P fulfills offline workflows, modularly integrating all feature data with async operations for remote workers.

## Detailed Design

Clean architecture: domain in core/domain/features/sync/, application layer in core/application/features/sync/, persistence via Drift in infrastructure/persistence/features/sync/, platform-specific in infrastructure/android/desktop/ for P2P. Core:

### Data Models

- **SyncMetadata** (core/domain/features/sync/models/sync_model.dart): entityType (enum), entityId (UUID), version (timestamp int), lastModified (DateTime), checksum (String).
- **SyncQueue**: Table for pending: operation (C/U/D), entityJson, deviceId.
- **Pairing Data**: Secure table: peerId (UUID), publicKey, lastSync (DateTime).
- **Storage**: Drift (SQLite) with indexes on entityId/version; migrations.

### Sync Protocol

- **Pairing**: qr_flutter for code generation (peerId/token), camera plugin for scanning; handshake via nearby_connections (mobile) or TCP sockets (desktop) in platform infra.
- **Data Transfer**: Diffs since last sync via DB timestamps; JSON serialize, libsodium encrypt, transfer over WiFi Direct/TCP.
- **Conflict Resolution**: Timestamp last-write-wins; merge lists (append tasks/habits) for ties; manual prompts via UI.
- **Selective Sync**: Toggles per type in settings module; excludes sensitive.
- **Offline Handling**: Queue in Drift, sync on reconnect.

### UI Components

- **Sync Settings Screen** (presentation/ui/features/sync/widgets/sync_settings.dart): Paired devices list, toggles, QR scanner.
- **Pairing Modal**: Camera view, progress.
- **Sync Status**: Nav badge for pending; history tab.
- **Conflict Resolver**: Dialog diffs for manual.

### APIs and Logic

- **Sync Manager**: Provider in sync_service.dart polls connectivity; initSync() pairs, pullChanges() receives, applyChanges() updates Drift with validation.
- **Diff Generation**: Comparator per entity in service (e.g., tasks by id/version).
- **Encryption**: libsodium payloads; Diffie-Hellman key exchange on pairing.
- **Cross-Platform**: nearby_connections (Android/mobile infra), LAN UDP (desktop); same-network limit.
- **Integration**: Depends on async lib for operations, all features for data (tasks/habits/notes), persistence for queue/state.

Trade-offs: Proximity/LAN limited (no relays for privacy); simple merge may need intervention. No enterprise scale (PRD 5.1.1).

Assumptions: Adapted to P2P (nearby_connections, qr_flutter, camera, libsodium) GPL-compatible over Firebase; Drift for state. Offline conflicts timestamp-based with user merge.

## Alternatives Considered

- **Cloud (Firebase)**: Rejected privacy/cost (PRD 5.1.3); P2P local.
- **Bluetooth-Only**: Inefficient large transfers; WiFi/TCP better.
- **Overwrite Always**: Risky loss (PRD 4.4); timestamp merge balances.
- **Full DB Dump**: Inefficient; diff reduces bandwidth.

## Implementation Notes

Phases: 1) Pairing/handshake (Week 7-8), 2) Diff/queue (Week 9), 3) Transfer (Week 10), 4) Conflict testing (Week 11). Challenges: Interruptions (retry queues). Outcomes: <10s for 1k entities LAN; 88% coverage. Integrated core modules.

## References

- PRD 3.3 (98-103), 4.4 (165-173).
- MODULES.md: Sync Module (188-214).
- Flutter: [Connectivity](https://pub.dev/packages/connectivity_plus).
- nearby_connections: [P2P](https://pub.dev/packages/nearby_connections).
- Drift: [ORM](https://pub.dev/packages/drift).

## History

Proposed: 2023. Implemented: v1.0.0.

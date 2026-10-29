import 'package:whph_sync_core/whph_sync_core.dart';

/// Members whose invite row stayed on [store]'s sealed origin, unsent, after
/// a key loss: no peer can ever learn them, so the app has to ask the user
/// to re-invite them.
Set<String> strandedMemberIds(SyncStore store, String ownMemberId) => {
      for (final pk in store.rowsOf(SecurityTables.member))
        if (pk != ownMemberId)
          if (store.storedCell(CellKey(SecurityTables.member, pk, CellKey.rowCol)) case final cell?
              when cell.manifest == null && cell.record.origin != store.localOrigin.hex)
            pk,
    };

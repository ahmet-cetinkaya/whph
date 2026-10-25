# T27 part 2 traceability

Run: `cd src && fvm flutter test test/integration/sync_acceptance/{scenarios_us2,scenarios_us4,edit_catalog,upgrade,edge_cases}_test.dart`
(`scenarios_us2` and `upgrade` carry the tag `t27-slow`; the tag is not declared in `dart_test.yaml`, which this part does not own, so the runner prints a warning.)

Every test is a real-device test: `AppDatabase.forTesting()` per device, file key store, membership with real Noise identities
paired through the real handover, the Drift capture triggers, the async session engine over `DriftSyncSessionHost`,
the real `SyncEngineService` (statuses, categories) over a loopback transport, and a real `LanSyncServer` and
WebSocket client where noted. Shared harness: `support2/` (`lab.dart`, `data_ops.dart`, `lan_support.dart`,
`pairing_support.dart`, `scenario_set.dart`, `services.dart`).

## Simulated, not real (US4)

`scenarios_us4_test.dart` is SIMULATED. No second release exists in this tree, so:

- a "release" is the protocol configuration of a real device: `v2` = (version 2, min 2), the newer compatible release
  = (version 3, min 2), the newer incompatible release = (version 3, min 3);
- the field a newer release adds (Scenario 4.3) is a cell for a column no release of this tree knows, written into the
  newer device's own change range (held `unknown` cell, signed in its manifest) and then relayed by real sessions.

Real: devices, membership, Noise sessions, negotiation, manifests, relay, storage of unknown cells. Not covered: builds
that differ in code (a real v0.x vs v1.x pair), which only a release-to-release test can show.

## Scenario and SC to test

| Id | Test (file) |
|---|---|
| Scenario 2.1 / SC-004 | `Scenario 2.1 / SC-004: 0 of 50 markers in the raw bytes, all 50 on B, plaintext control sees all 50` (scenarios_us2) |
| Scenario 2.2 / SC-005 | `Scenario 2.2 / SC-005: 100 non-member connections ...`, `Scenario 2.2 / SC-005: 100 changes injected by a non-member ...` (scenarios_us2) |
| Scenario 2.3 / SC-005 | `Scenario 2.3 / SC-005: 100 injected forged frames ...`, `... 100 altered captured frames ...`, `... 100 replayed captured frames ...`; positive control `Scenarios 2.2 and 2.3: after the attacks a genuine member still syncs` (scenarios_us2) |
| Scenario 2.4 / SC-006 | `Scenario 2.4 / SC-006: 100 attempts of C with each remaining member fail`, `... the remaining members do not start sessions with C either`, `... a change captured after the removal cannot be read by C` (scenarios_us2) |
| SC-014 | `SC-014: 100 outgoing envelopes opened with a non-member keyring yield 0 readable items`, `SC-014: a stored held envelope is ciphertext only ...`, `SC-014: 100 sessions of the non-member with the captured data apply 0 items on members` (scenarios_us2) |
| Scenario 2.5 | `Scenario 2.5: a scan after the code expired ...`, `Scenario 2.5: a scan of a code that was already used ...` (scenarios_us2) |
| Scenario 4.1 | `Scenario 4.1 [simulated]: A (v3 min2) and B (v2) exchange everything, like equal releases`, `... the older release (v2) can start the session too` (scenarios_us4) |
| Scenario 4.2 | `Scenario 4.2 / SC-008 [simulated]: 0 items are exchanged and both ends name the older device`, `Scenario 4.2 [simulated]: the engine of each device records "needs update" ...`, `... the message template names the device`, `... after the older device updates (min3), they sync again` (scenarios_us4) |
| Scenario 4.3 | `Scenario 4.3 [simulated]: C receives the future field exactly as A wrote it, through B` (scenarios_us4) |
| SC-008 | `SC-008 [simulated] Scenario 1.1` .. `1.9 on compatible different releases (A v3 min2, B v2, C v2)`, the same nine on equal releases as control, plus the Scenario 4.2 tests (scenarios_us4) |
| SC-009 | one test per action: `SC-009 <type>: <action> is visible on B after one session` (50 actions) and `SC-009: the catalog covers every FR-050 data type`; `SC-009 paired device: ...` (edit_catalog) |
| Scenario 5.1 | `Scenario 5.1: notes reordered on A show the same order on B`; action `note.reorder` (edit_catalog) |
| Scenario 5.2 | `Scenario 5.2: time logged on a habit on A is the habit time on B` (edit_catalog) |
| Scenario 5.3 | `Scenario 5.3: B keeps the remote origin and HLC, its next_seq stays, no own-origin cell appears` (edit_catalog) |
| SC-010 | `SC-010 large_usage / empty / duplicates: 100% of items and fields are kept (FR-060)`, `... the fixture holds 3+ years of app usage and all of it survives`, `... every legacy pairing needs re-pairing and none is synced (FR-061)` (upgrade) |

## Edge cases

| Id | Edge case | Test (edge_cases) |
|---|---|---|
| EC-01 | empty data | `EC-01 empty data: ...` |
| EC-02 | first sync of a new member with existing data | `EC-02 first sync of a new member ...` |
| EC-03 | delete then re-create | `EC-03 delete then re-create ...` |
| EC-04 | large backlog across sessions | `EC-04 large backlog across sessions: 1500 items ...` |
| EC-05 | simultaneous start | `EC-05 simultaneous start ...` |
| EC-06 | SQLITE_FULL injection retried with data intact | `EC-06 SQLITE_FULL injection ...` |
| EC-07 | duplicate merge while editing | `EC-07 duplicate merge while editing ...` |
| EC-08 | import-replace with peers (union, same-pk re-import) | `EC-08 import-replace with peers ...` |
| EC-09 | restore old snapshot with kept tombstones, 3 devices (U10) | `EC-09 restore of an old snapshot ...` |
| EC-10 | relay order that stages a row | `EC-10 relay order that stages a row ...` |
| EC-11 | cascade revival across 3 devices | `EC-11 cascade revival across 3 devices ...` |
| EC-12 | group switch | `EC-12 group switch ...` |
| EC-13 | set-total concurrent with an add | `EC-13 task time ...`, `EC-13 habit time ...` |
| EC-14 | reset database on a paired device | `EC-14 reset database on a paired device ...` |

## Gaps (what is not automated here)

- **UI screens.** The catalog drives the actions below the widgets (SQL writes of the repository columns and the real
  services for time buckets, note order and import). The widgets that call them are not driven headless.
- **Scenario 4.2 message naming.** The sessions of both devices name the older device (`SessionFailed.mustUpdate`, asserted).
  The sync UI shows `{device} needs a newer version` with the *peer's* name (`SyncResultTexts.categoryText(..., member.name)`),
  and nothing consumes `mustUpdate`. On the newer device the peer is the one to update (correct); on the older one it names
  the newer peer. Asserted: the template and the recorded category; not fixable without a UI and locale change (reported).
- **Real second release (US4)**: simulated, see above.
- **SC-014 "applied"** is shown by sessions of a non-member that reach no state change on members; there is no API that
  feeds raw envelopes to a non-member store, so "applied by the non-member" has no other path.
- **EC-07** runs the runtime merge of identically keyed items; the upgrade-time merge with edits in between is in T17's
  `upgrade_job_test.dart` acceptance 8.
- **EC-06** injects `PRAGMA max_page_count` on an in-memory SQLite, which raises the same `SQLITE_FULL` result code a
  full disk does; a physically full volume is not exercised.
- **SC-010 timing**: `large_usage` (>= 150,000 usage records over 3+ years) is upgraded for correctness only; the runtime
  budget is T17/T28.

## Production bugs found by these suites (fixed in `src/lib`)

1. `drift_sync_store_port.dart` `storedCell`: a relayed `unknown` held cell was not found by key, so the sender's
   scan looped forever (session hang). Found by Scenario 4.3. Test: Scenario 4.3.
2. `sync_trigger_generator.dart` (+ `syncCaptureVersion` v38-3 to v38-4): the update trigger of a row-level table wrote the
   `*` cell on every update, including a soft delete, stamped after the tombstone; peers then kept the row alive (deleted
   tag links, time records, habit records, rules came back). Found by SC-009 `task_tag.remove`. Tests: every
   `*.remove` / `*.unlink` action of the catalog.
3. `drift_sync_change_store.dart`: the `*` cell of `task_time_record_table` did not carry `created_date`, which holds the hour
   bucket of the record; the receiver stamped it with the apply time, so a set-total on another device summed the wrong
   day. Found by EC-13 (task time) and checked by `task_time.add` of the catalog.

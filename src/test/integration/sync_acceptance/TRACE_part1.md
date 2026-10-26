# T27 part 1 trace: US1 and US3 acceptance

Run: `cd src && fvm flutter test test/integration/sync_acceptance/scenarios_us1_test.dart test/integration/sync_acceptance/scenarios_us3_test.dart`
(about 25 s and 10 s). Every session goes through `SyncEngineService`, the Drift session host and an in-memory
loopback link; devices are real `AppDatabase.forTesting()` databases with key files and real pairing (`support1/`).

## US1 (`scenarios_us1_test.dart`)

| Id | Test name | Notes |
|---|---|---|
| Scenario 1.1 | `Scenario 1.1 different fields of one task both survive` | title on A, reminder on B; both fields and full table equal on both |
| Scenario 1.2 | `Scenario 1.2 same field: the later recorded edit wins on both devices` | B's clock is 1 h ahead, so its body wins; A's body is gone |
| Scenario 1.3 | `Scenario 1.3 causal order beats clocks: ...` | A runs 3 h ahead; B edits after receiving A's edit and wins. Positive control in the same test: a concurrent edit loses to A's fast clock (FR-004) |
| Scenario 1.4 | `Scenario 1.4 a change relayed through B ...` | A-B-C chain (C paired through B, A and C never connect) compared with the direct A-C result of the same conflict |
| Scenario 1.5 | `Scenario 1.5 an older edit arriving after a newer one ...` | B receives C's newer edit first, then A's older one; asserts B's state in between |
| Scenario 1.6 | `Scenario 1.6 a deletion made after seeing an edit ...` | B runs 3 h ahead, its edit reaches A, A deletes; deleted on both |
| Scenario 1.7 | `Scenario 1.7 a concurrent delete and edit ...` | both orders (delete later, edit later); same outcome on both devices each time |
| Scenario 1.8 | `Scenario 1.8 an interrupted session ...` | 400 notes, sessions cut after 6, 14, 40 frames (asserts at least one was cut), then a complete session; rows equal and A's origin sequence numbers on B equal A's (exactly once, none skipped) |
| Scenario 1.9 | `Scenario 1.9 a failed item ...` | a trigger makes B refuse one row: category `someItemsFailed`, `SessionPartial`, other row kept; after the fault is removed the next session applies it |
| SC-002 | `SC-002 every Scenario 1.1 to 1.9 shows ...` | passes only when all nine scenario tests ran and passed in the same file run (each records its pass); it fails if run alone with `--plain-name` |
| SC-003 | `SC-003 20 fault-injection runs: ...` | 20 runs, alternating note and task rows, the failing row at a different position each run: every run reports `someItemsFailed`, keeps the other rows, and applies the item in the first session after the fault is removed |

## US3 (`scenarios_us3_test.dart`)

| Id | Test name | Notes |
|---|---|---|
| Scenario 3.1 | `Scenario 3.1 a habit day marked done on A and skipped on B ...` | real `HabitRecordOperationsService` (deterministic id); one record per device with B's later status |
| Scenario 3.2 | `Scenario 3.2 two devices each generating the next occurrence ...` | real `TaskRecurrenceService` + `SaveTaskCommand` on both devices; both derive the same identity; one occurrence on each device |
| Scenario 3.3 | `... Scenario 3.3 two settings with the same key ...` | production `SyncUpgradeJob` over the v37 `duplicates` fixture opened through the real v37 to v38 migration; one row per duplicated key, `WORK_TIME` keeps the most recent value |
| Scenario 3.4 | `... Scenario 3.4 merged duplicate occurrences ...` | same fixture; for each duplicate occurrence group the single survivor carries every tag and every time record of its members |
| SC-007 (upgrade) | `... SC-007 after upgrading duplicates ...` and `... duplicates_shuffled ...` | the FR-030 violation counter (independent SQL, `support1/identity_harness.dart`) is 0; live links equal the distinct pre-merge (item, tag) pairs; live time records equal the pre-merge count; no child item lost or orphaned |
| SC-007 (runtime) | `SC-007 after syncing identity-rule items created on two devices ...` | both devices create habit record, setting, task/habit/tag-tag links, built-in status and recurring occurrence offline through the app commands; after sync each exists once on both devices, violation counter 0, one member entry per device |

## Production fix found by the suite

`TaskRecurrenceService` passed the deterministic occurrence id as `SaveTaskCommand.id`, which `SaveTaskCommandHandler`
treats as an update ("Task with id ... not found"), so no recurring occurrence could be created. Fix: new
`SaveTaskCommand.newTaskId` (creation id); the service uses it. Files:
`src/lib/core/application/features/tasks/commands/save_task_command.dart`,
`src/lib/core/application/features/tasks/services/task_recurrence_service.dart`.

## Gaps and limits

- Clock skew is modelled by moving a device's hybrid clock and engine clock ahead (hybrid clocks never run
  backwards, and the capture triggers read the real wall clock), so "B is 3 hours behind A" is tested as "A is 3 hours
  ahead of B".
- FR-004 exact-tie ordering (equal hybrid times) is not forced by an acceptance test here; the tie rule is covered at the merge-algebra level by
  `packages/whph_sync_core/test/merge/cell_merge_algebra_test.dart` and `test/clock/hlc_test.dart`, not by this suite.
- SC-007 "app usage tag" and "note tag" links are covered only in the upgrade half (fixture), not in the runtime half.
- SC-007 time-record count "minus exact duplicates": the fixture merges lose no time record, so the assertion is
  equality of live counts.

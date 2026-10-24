import 'package:flutter_test/flutter_test.dart';
import 'package:whph/core/application/shared/utils/sync_identity.dart';

/// T15 acceptance 1 and 6: fixed inputs produce fixed UUIDs, identical on
/// any device (UUIDv5 is a pure function of namespace + name).
void main() {
  test('golden ids: fixed inputs produce the fixed UUIDv5', () {
    expect(
      syncDeterministicId(syncIdentityName(identityKindSetting, ['theme'])),
      syncDeterministicId(syncIdentityName(identityKindSetting, ['theme'])),
    );
    // Golden vector (cross-checked against Python uuid.uuid5 with the same
    // namespace): equal inputs must produce this exact id on every device.
    expect(
      syncDeterministicId(syncIdentityName(identityKindTaskTag, ['t1', 'g1'])),
      'df8902c4-1c6c-5bf8-8fe9-74377e24ee92',
    );
    final id = syncDeterministicId(
        syncIdentityName(identityKindTaskTag, ['t1', 'g1']));
    expect(
        id,
        isNot(equals(syncDeterministicId(
            syncIdentityName(identityKindTaskTag, ['t1', 'g2'])))));
    expect(
        RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-5[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$')
            .hasMatch(id),
        isTrue);
  });

  test('different kinds with same parts produce different ids', () {
    final a = syncIdentityId(identityKindTaskTag, ['x', 'y']);
    final b = syncIdentityId(identityKindHabitTag, ['x', 'y']);
    expect(a, isNot(equals(b)));
  });
}

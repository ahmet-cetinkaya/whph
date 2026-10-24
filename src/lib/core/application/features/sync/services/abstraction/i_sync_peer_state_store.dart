/// Local-only per-peer status that the membership service owns (D7, D13):
/// whether a member must be paired again, and the address lists the outbound
/// static-key check corrects.
abstract interface class ISyncPeerStateStore {
  /// Member ids currently marked "needs re-pairing".
  Future<Set<String>> peersNeedingRepairing();

  Future<void> markNeedsRepairing(String memberId);

  Future<void> clearNeedsRepairing(String memberId);

  /// Moves [address] from the list of [fromMemberId] to the list of
  /// [toMemberId] (an address answered with another member's static key).
  Future<void> moveAddress(String address, {required String fromMemberId, required String toMemberId});

  Future<List<String>> addressesOf(String memberId);
}

import 'dart:convert';

/// D6b: the predicate of the resumable `reauthor` upgrade phase, stored in
/// `sync_state.reauthor_spec`.
///
/// - [adopt] (restore, key_lost): cells of the sealed origin that no peer can
///   hold, i.e. without a manifest or above the sent mark, move to the new
///   origin.
/// - [all] (group_switch): every clock row not on the new origin is
///   re-authored.
class ReauthorSpec {
  static const String _kindAdopt = 'adopt';
  static const String _kindAll = 'all';

  final String kind;
  final int newOriginId;
  final int? oldOriginId;
  final int? sentMark;

  const ReauthorSpec._(
      this.kind, this.newOriginId, this.oldOriginId, this.sentMark);

  const ReauthorSpec.adopt(
      {required int oldOriginId, required int newOriginId, int? sentMark})
      : this._(_kindAdopt, newOriginId, oldOriginId, sentMark);

  const ReauthorSpec.all({required int newOriginId})
      : this._(_kindAll, newOriginId, null, null);

  factory ReauthorSpec.decode(String text) {
    final json = jsonDecode(text) as Map<String, dynamic>;
    return ReauthorSpec._(json['kind'] as String, json['new'] as int,
        json['old'] as int?, json['sentMark'] as int?);
  }

  String encode() => jsonEncode({
        'kind': kind,
        'new': newOriginId,
        'old': oldOriginId,
        'sentMark': sentMark
      });

  /// SQL over `sync_clock` and its bind arguments (columns `origin_id`,
  /// `manifest_id`, `origin_seq`).
  (String, List<Object?>) get predicate => kind == _kindAdopt
      ? (
          'origin_id = ? AND (manifest_id IS NULL OR (? IS NOT NULL AND origin_seq > ?))',
          [oldOriginId, sentMark, sentMark]
        )
      : ('origin_id != ?', [newOriginId]);
}

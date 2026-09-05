/// Habit types are persisted by [id], not by declaration order, so variants can
/// be reordered without rewriting stored rows.
enum HabitType {
  good(0),
  bad(1);

  const HabitType(this.id);

  final int id;

  /// Unknown ids come from rows written by a newer build or from corrupted data,
  /// and default to [good] like every other legacy habit.
  static HabitType fromId(int? id) => switch (id) {
        1 => HabitType.bad,
        _ => HabitType.good,
      };

  static HabitType fromJson(Object? value) => switch (value) {
        'bad' => HabitType.bad,
        _ => HabitType.good,
      };
}

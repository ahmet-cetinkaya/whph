enum HabitType {
  good,
  bad;

  static HabitType fromJson(Object? value) => switch (value) {
        'bad' => HabitType.bad,
        _ => HabitType.good,
      };
}

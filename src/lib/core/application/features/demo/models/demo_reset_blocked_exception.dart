/// A demo reset, clear or initialization was refused because the device is
/// paired (U6): it would truncate the user tables and rewrite them as local
/// edits of a group the data belongs to. Nothing was changed.
class DemoResetBlockedException implements Exception {
  const DemoResetBlockedException();

  @override
  String toString() =>
      'DemoResetBlockedException: demo data cannot be reset while the device is paired';
}

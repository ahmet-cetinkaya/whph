import 'package:nanoid2/nanoid2.dart';

class KeyHelper {
  static String generateStringId({int length = 21}) {
    return nanoid(length: length);
  }

  // Maximum value for a Integer is 2^31 - 1 = 2,147,483,647
  static const int maxNumericLength = 9;

  /// Generates a numeric ID that is safe to use with Integer type
  /// Returns a 9-digit unique numeric identifier for defensive programming
  static int generateNumericId({int length = maxNumericLength}) {
    if (length < 1) throw ArgumentError('Length must be greater than 0');
    if (length > maxNumericLength) throw ArgumentError('Length must be less than or equal to $maxNumericLength');

    final generatedId = int.parse(nanoid(length: maxNumericLength, alphabet: '0123456789'));
    return generatedId;
  }
}

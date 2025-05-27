import 'package:flutter/material.dart';

extension ColorExtensions on Color {
  /// Converts a Color object to a hex string representation without the FF alpha prefix
  /// This matches the format used throughout the application for storing colors
  String toHexString() {
    // Convert to hex and remove the alpha channel (FF prefix)
    final hexValue = toARGB32().toRadixString(16).toUpperCase();
    // Remove the first two characters (alpha channel) to match app format
    return hexValue.length == 8 ? hexValue.substring(2) : hexValue;
  }
}

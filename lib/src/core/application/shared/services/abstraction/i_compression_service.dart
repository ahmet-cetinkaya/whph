import 'dart:typed_data';

/// Interface for compression and decompression operations
abstract class ICompressionService {
  /// Compresses data in a background isolate
  Future<Uint8List> compressInBackground(Uint8List input);

  /// Decompresses streamed data in a background isolate
  Stream<Uint8List> decompressStreamedInBackground(Stream<List<int>> input);

  /// Validates the header of a .whph file
  bool validateHeader(Uint8List data);

  /// Creates a .whph file with proper header and checksum
  Future<Uint8List> createWhphFile(String jsonData);

  /// Extracts JSON data from a .whph file
  Future<String> extractFromWhphFile(Uint8List whphData);

  /// Validates checksum of .whph file
  Future<bool> validateChecksum(Uint8List whphData);
}
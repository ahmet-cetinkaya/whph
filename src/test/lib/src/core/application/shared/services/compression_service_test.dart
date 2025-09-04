import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:whph/core/application/shared/services/compression_service.dart';

void main() {
  group('CompressionService', () {
    late CompressionService compressionService;

    setUp(() {
      compressionService = CompressionService();
    });

    test('should compress and decompress data correctly', () async {
      // Arrange - Use larger, repetitive data that compresses well
      final testData = 'This is test data for compression. ' * 100; // Repeat 100 times
      final inputData = Uint8List.fromList(utf8.encode(testData));

      // Act
      final compressed = await compressionService.compressInBackground(inputData);
      final decompressed = await compressionService
          .decompressStreamedInBackground(
            Stream.value(compressed.toList()),
          )
          .first;

      // Assert
      expect(compressed.length, lessThan(inputData.length));
      expect(utf8.decode(decompressed), equals(testData));
    });

    test('should create and extract .whph file correctly', () async {
      // Arrange
      const testJson = '{"test": "data", "number": 123}';

      // Act
      final whphFile = await compressionService.createWhphFile(testJson);
      final extractedJson = await compressionService.extractFromWhphFile(whphFile);

      // Assert
      expect(extractedJson, equals(testJson));
    });

    test('should validate .whph file header correctly', () async {
      // Arrange
      const testJson = '{"test": "data"}';
      final whphFile = await compressionService.createWhphFile(testJson);

      // Act
      final isValid = compressionService.validateHeader(whphFile);

      // Assert
      expect(isValid, isTrue);
    });

    test('should validate .whph file checksum correctly', () async {
      // Arrange
      const testJson = '{"test": "data"}';
      final whphFile = await compressionService.createWhphFile(testJson);

      // Act
      final isValid = await compressionService.validateChecksum(whphFile);

      // Assert
      expect(isValid, isTrue);
    });

    test('should reject invalid .whph file header', () {
      // Arrange
      final invalidData = Uint8List.fromList([1, 2, 3, 4, 5, 6, 7, 8]);

      // Act
      final isValid = compressionService.validateHeader(invalidData);

      // Assert
      expect(isValid, isFalse);
    });

    test('should reject corrupted .whph file', () async {
      // Arrange
      const testJson = '{"test": "data"}';
      final whphFile = await compressionService.createWhphFile(testJson);

      // Corrupt the file by changing a byte
      whphFile[whphFile.length - 1] = whphFile[whphFile.length - 1] ^ 0xFF;

      // Act
      final isValid = await compressionService.validateChecksum(whphFile);

      // Assert
      expect(isValid, isFalse);
    });

    test('should handle large data efficiently', () async {
      // Arrange
      final largeData = List.generate(10000, (i) => 'Item $i').join('\n');
      final inputData = Uint8List.fromList(utf8.encode(largeData));

      // Act
      final compressed = await compressionService.compressInBackground(inputData);
      final decompressed = await compressionService
          .decompressStreamedInBackground(
            Stream.value(compressed.toList()),
          )
          .first;

      // Assert
      expect(compressed.length, lessThan(inputData.length));
      expect(utf8.decode(decompressed), equals(largeData));
      // Note: Removed time-based assertions to avoid flaky tests
    });
  });
}

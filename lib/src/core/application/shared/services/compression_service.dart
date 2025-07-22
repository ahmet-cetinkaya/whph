import 'dart:convert';
import 'dart:async';
import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:whph/src/core/application/shared/services/abstraction/i_compression_service.dart';

/// Service for handling compression and decompression operations in background isolates
class CompressionService implements ICompressionService {
  static const String _whphHeader = 'WHPH';
  static const int _version = 1;

  /// Compresses data in a background isolate
  @override
  Future<Uint8List> compressInBackground(Uint8List input) async {
    return await compute(_compressData, input);
  }

  /// Decompresses streamed data in a background isolate
  @override
  Stream<Uint8List> decompressStreamedInBackground(Stream<List<int>> input) async* {
    await for (final chunk in input) {
      final decompressed = await compute(_decompressData, Uint8List.fromList(chunk));
      yield decompressed;
    }
  }

  /// Validates the header of a .whph file
  @override
  bool validateHeader(Uint8List data) {
    if (data.length < 8) return false;
    
    final header = String.fromCharCodes(data.sublist(0, 4));
    final version = data.buffer.asByteData().getUint32(4, Endian.little);
    
    return header == _whphHeader && version == _version;
  }

  /// Creates a .whph file with proper header and checksum
  @override
  Future<Uint8List> createWhphFile(String jsonData) async {
    return await compute(_createWhphFileIsolate, jsonData);
  }

  /// Extracts JSON data from a .whph file
  @override
  Future<String> extractFromWhphFile(Uint8List whphData) async {
    return await compute(_extractFromWhphFileIsolate, whphData);
  }

  /// Validates checksum of .whph file
  @override
  Future<bool> validateChecksum(Uint8List whphData) async {
    return await compute(_validateChecksumIsolate, whphData);
  }

  // Static methods for isolate execution

  static Uint8List _compressData(Uint8List input) {
    final encoder = GZipEncoder();
    final compressed = encoder.encode(input);
    return Uint8List.fromList(compressed);
  }

  static Uint8List _decompressData(Uint8List input) {
    final decoder = GZipDecoder();
    final decompressed = decoder.decodeBytes(input);
    return Uint8List.fromList(decompressed);
  }

  static Uint8List _createWhphFileIsolate(String jsonData) {
    final jsonBytes = utf8.encode(jsonData);
    final compressed = _compressData(Uint8List.fromList(jsonBytes));
    
    // Calculate checksum (simple CRC32)
    final crc = _calculateCrc32(compressed);
    
    // Create header: WHPH (4 bytes) + version (4 bytes) + checksum (4 bytes) + data length (4 bytes)
    final headerSize = 16;
    final result = Uint8List(headerSize + compressed.length);
    final byteData = result.buffer.asByteData();
    
    // Write header
    result.setRange(0, 4, _whphHeader.codeUnits);
    byteData.setUint32(4, _version, Endian.little);
    byteData.setUint32(8, crc, Endian.little);
    byteData.setUint32(12, compressed.length, Endian.little);
    
    // Write compressed data
    result.setRange(headerSize, headerSize + compressed.length, compressed);
    
    return result;
  }

  static String _extractFromWhphFileIsolate(Uint8List whphData) {
    if (whphData.length < 16) {
      throw Exception('Invalid .whph file: too small');
    }
    
    final byteData = whphData.buffer.asByteData();
    
    // Validate header
    final header = String.fromCharCodes(whphData.sublist(0, 4));
    final version = byteData.getUint32(4, Endian.little);
    final storedChecksum = byteData.getUint32(8, Endian.little);
    final dataLength = byteData.getUint32(12, Endian.little);
    
    if (header != _whphHeader) {
      throw Exception('Invalid .whph file: wrong header');
    }
    
    if (version != _version) {
      throw Exception('Unsupported .whph file version: $version');
    }
    
    if (whphData.length < 16 + dataLength) {
      throw Exception('Invalid .whph file: incomplete data');
    }
    
    // Extract compressed data
    final compressedData = whphData.sublist(16, 16 + dataLength);
    
    // Validate checksum
    final calculatedChecksum = _calculateCrc32(compressedData);
    if (calculatedChecksum != storedChecksum) {
      throw Exception('Invalid .whph file: checksum mismatch');
    }
    
    // Decompress data
    final decompressed = _decompressData(compressedData);
    return utf8.decode(decompressed);
  }

  static bool _validateChecksumIsolate(Uint8List whphData) {
    try {
      if (whphData.length < 16) return false;
      
      final byteData = whphData.buffer.asByteData();
      final storedChecksum = byteData.getUint32(8, Endian.little);
      final dataLength = byteData.getUint32(12, Endian.little);
      
      if (whphData.length < 16 + dataLength) return false;
      
      final compressedData = whphData.sublist(16, 16 + dataLength);
      final calculatedChecksum = _calculateCrc32(compressedData);
      
      return calculatedChecksum == storedChecksum;
    } catch (e) {
      return false;
    }
  }

  static int _calculateCrc32(Uint8List data) {
    // Simple CRC32 implementation
    const int polynomial = 0xEDB88320;
    int crc = 0xFFFFFFFF;
    
    for (int byte in data) {
      crc ^= byte;
      for (int i = 0; i < 8; i++) {
        if (crc & 1 != 0) {
          crc = (crc >> 1) ^ polynomial;
        } else {
          crc >>= 1;
        }
      }
    }
    
    return crc ^ 0xFFFFFFFF;
  }
}
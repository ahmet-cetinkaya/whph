import 'dart:convert';
import 'dart:async';
import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:whph/src/core/application/shared/services/abstraction/i_compression_service.dart';

/// Service for handling compression and decompression operations in background isolates
class CompressionService implements ICompressionService {
  static const String _whphHeader = 'WHPH';
  static const int _version = 1;
  static const int _headerSize = 16;
  static const int _headerFieldSize = 4;
  static const int _versionOffset = 4;
  static const int _checksumOffset = 8;
  static const int _dataLengthOffset = 12;

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
    if (data.length < _checksumOffset) return false;
    
    final header = String.fromCharCodes(data.sublist(0, _headerFieldSize));
    final version = data.buffer.asByteData().getUint32(_versionOffset, Endian.little);
    
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
    
    // Calculate checksum using standard library CRC32
    final crc = getCrc32(compressed);
    
    // Create header: WHPH (4 bytes) + version (4 bytes) + checksum (4 bytes) + data length (4 bytes)
    final result = Uint8List(_headerSize + compressed.length);
    final byteData = result.buffer.asByteData();
    
    // Write header
    result.setRange(0, _headerFieldSize, _whphHeader.codeUnits);
    byteData.setUint32(_versionOffset, _version, Endian.little);
    byteData.setUint32(_checksumOffset, crc, Endian.little);
    byteData.setUint32(_dataLengthOffset, compressed.length, Endian.little);
    
    // Write compressed data
    result.setRange(_headerSize, _headerSize + compressed.length, compressed);
    
    return result;
  }

  static String _extractFromWhphFileIsolate(Uint8List whphData) {
    final headerInfo = _parseWhphHeader(whphData);
    
    // Extract compressed data
    final compressedData = whphData.sublist(_headerSize, _headerSize + headerInfo.dataLength);
    
    // Validate checksum
    final calculatedChecksum = getCrc32(compressedData);
    if (calculatedChecksum != headerInfo.storedChecksum) {
      throw Exception('Invalid .whph file: checksum mismatch');
    }
    
    // Decompress data
    final decompressed = _decompressData(compressedData);
    return utf8.decode(decompressed);
  }

  static bool _validateChecksumIsolate(Uint8List whphData) {
    try {
      final headerInfo = _parseWhphHeader(whphData);
      final compressedData = whphData.sublist(_headerSize, _headerSize + headerInfo.dataLength);
      final calculatedChecksum = getCrc32(compressedData);
      
      return calculatedChecksum == headerInfo.storedChecksum;
    } catch (e) {
      return false;
    }
  }

  /// Helper method to parse .whph file header and validate it
  static _WhphHeaderInfo _parseWhphHeader(Uint8List whphData) {
    if (whphData.length < _headerSize) {
      throw Exception('Invalid .whph file: too small');
    }
    
    final byteData = whphData.buffer.asByteData();
    
    // Parse header fields
    final header = String.fromCharCodes(whphData.sublist(0, _headerFieldSize));
    final version = byteData.getUint32(_versionOffset, Endian.little);
    final storedChecksum = byteData.getUint32(_checksumOffset, Endian.little);
    final dataLength = byteData.getUint32(_dataLengthOffset, Endian.little);
    
    // Validate header
    if (header != _whphHeader) {
      throw Exception('Invalid .whph file: wrong header');
    }
    
    if (version != _version) {
      throw Exception('Unsupported .whph file version: $version');
    }
    
    if (whphData.length < _headerSize + dataLength) {
      throw Exception('Invalid .whph file: incomplete data');
    }
    
    return _WhphHeaderInfo(
      storedChecksum: storedChecksum,
      dataLength: dataLength,
    );
  }
}

/// Helper class to hold parsed header information
class _WhphHeaderInfo {
  final int storedChecksum;
  final int dataLength;
  
  _WhphHeaderInfo({
    required this.storedChecksum,
    required this.dataLength,
  });
}
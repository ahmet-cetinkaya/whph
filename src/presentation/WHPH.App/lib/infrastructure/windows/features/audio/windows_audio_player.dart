import 'dart:async';
import 'dart:io';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';
import 'package:flutter/scheduler.dart';
import 'package:acore/acore.dart';

class WindowsAudioPlayer implements ISoundPlayer {
  final AudioPlayer _audioPlayer = AudioPlayer();
  final Map<String, Uint8List> _soundCache = {};
  bool _isInitialized = false;
  double _currentVolume = 1.0;

  // Loop context preservation
  bool _wasLooping = false;
  String? _loopingSoundPath;
  bool _isPlayingOneTimeSound = false;
  bool _listenerSetup = false;
  StreamSubscription<void>? _completionSubscription;
  Timer? _completionTimer;

  /// Ensures audio operations run on the main thread to avoid Windows threading issues
  Future<T> _runOnMainThread<T>(Future<T> Function() operation) async {
    if (Platform.isWindows) {
      // Use SchedulerBinding to ensure we're on the main thread
      final completer = Completer<T>();
      SchedulerBinding.instance.addPostFrameCallback((_) async {
        try {
          final result = await operation();
          completer.complete(result);
        } catch (e) {
          completer.completeError(e);
        }
      });
      SchedulerBinding.instance.ensureVisualUpdate();
      return completer.future;
    } else {
      return operation();
    }
  }

  /// Converts Opus file path to MP3 equivalent for Windows fallback
  String _getWindowsAudioPath(String originalPath) {
    if (Platform.isWindows && originalPath.endsWith('.opus')) {
      return originalPath.replaceAll('.opus', '.mp3');
    }
    return originalPath;
  }

  /// Starts a timer to handle completion on Windows (avoids threading issues with event listeners)
  void _startCompletionTimer(String audioPath) {
    _completionTimer?.cancel();

    // Estimate duration based on typical sound lengths
    // Most UI sounds are short, so we'll use a conservative estimate
    const estimatedDuration = Duration(seconds: 3);

    _completionTimer = Timer(estimatedDuration, () {
      if (_isPlayingOneTimeSound && _loopingSoundPath != null) {
        _resumeLoopingSound();
      }
    });
  }

  Future<void> _ensureInitialized(String path, {bool requestAudioFocus = true}) async {
    final audioPath = _getWindowsAudioPath(path);

    if (!_soundCache.containsKey(audioPath)) {
      try {
        _soundCache[audioPath] = (await rootBundle.load(audioPath)).buffer.asUint8List();
      } catch (e) {
        // If MP3 fallback fails, try original path
        if (audioPath != path) {
          try {
            _soundCache[path] = (await rootBundle.load(path)).buffer.asUint8List();
            _soundCache[audioPath] = _soundCache[path]!; // Cache under both keys
          } catch (originalError) {
            // If both fail, disable audio silently as per documentation
            return;
          }
        } else {
          // If original path fails, disable audio silently
          return;
        }
      }
    }

    if (!_isInitialized) {
      try {
        // Configure audio context based on whether we want audio focus
        await _runOnMainThread(() => _audioPlayer.setAudioContext(
              AudioContext(
                android: AudioContextAndroid(
                  audioFocus: requestAudioFocus ? AndroidAudioFocus.gainTransientMayDuck : AndroidAudioFocus.none,
                ),
              ),
            ));

        await _runOnMainThread(() => _audioPlayer.setSourceBytes(_soundCache[audioPath]!));
        await _runOnMainThread(() => _audioPlayer.setVolume(0));
        await _runOnMainThread(() => _audioPlayer.stop());
        _isInitialized = true;
      } catch (e) {
        // Disable audio silently if initialization fails
        return;
      }
    }

    // Setup completion listener once - avoid event streams on Windows due to threading issues
    if (!_listenerSetup) {
      if (Platform.isWindows) {
        // On Windows, skip event listeners entirely to avoid threading issues
        // Loop resumption will be handled differently if needed
      } else {
        // On other platforms, use direct listener
        _completionSubscription = _audioPlayer.onPlayerComplete.listen((event) {
          if (_isPlayingOneTimeSound && _loopingSoundPath != null) {
            _resumeLoopingSound();
          }
        });
      }
      _listenerSetup = true;
    }
  }

  @override
  void play(String path, {bool requestAudioFocus = true, double? volume}) async {
    try {
      await _ensureInitialized(path, requestAudioFocus: requestAudioFocus);
      final audioPath = _getWindowsAudioPath(path);

      // Check if audio is available
      if (!_soundCache.containsKey(audioPath)) {
        return; // Silently fail if no audio available
      }

      // Use provided volume or fall back to current volume
      final playVolume = volume ?? _currentVolume;

      // Check if we're currently looping and this is a different sound
      final wasCurrentlyLooping = _wasLooping && _loopingSoundPath != null && _loopingSoundPath != path;

      if (wasCurrentlyLooping && requestAudioFocus) {
        // We're interrupting a looping sound with a one-time sound
        _isPlayingOneTimeSound = true;

        // Stop current looping sound
        await _runOnMainThread(() => _audioPlayer.stop());

        // Play the one-time sound
        await _runOnMainThread(() => _audioPlayer.setSourceBytes(_soundCache[audioPath]!));
        await _runOnMainThread(() => _audioPlayer.setReleaseMode(ReleaseMode.release)); // One-time play
        await _runOnMainThread(() => _audioPlayer.setVolume(playVolume));
        await _runOnMainThread(() => _audioPlayer.resume());

        // On Windows, use timer instead of event listener to avoid threading issues
        if (Platform.isWindows) {
          _startCompletionTimer(audioPath);
        }
      } else {
        // Normal play - either first sound or replacing current sound
        await _runOnMainThread(() => _audioPlayer.stop());
        await _runOnMainThread(() => _audioPlayer.setSourceBytes(_soundCache[audioPath]!));
        await _runOnMainThread(() => _audioPlayer.setVolume(playVolume));
        await _runOnMainThread(() => _audioPlayer.resume());

        // Set looping sound path if we're in loop mode
        if (_wasLooping) {
          _loopingSoundPath = path;
        }
      }
    } catch (e) {
      // Silently fail if audio playback fails
      return;
    }
  }

  Future<void> _resumeLoopingSound() async {
    if (_loopingSoundPath != null && _wasLooping && _isPlayingOneTimeSound) {
      _isPlayingOneTimeSound = false;
      final audioPath = _getWindowsAudioPath(_loopingSoundPath!);

      try {
        // Resume the looping sound
        await _runOnMainThread(() => _audioPlayer.setSourceBytes(_soundCache[audioPath]!));
        await _runOnMainThread(() => _audioPlayer.setReleaseMode(ReleaseMode.loop));
        await _runOnMainThread(() => _audioPlayer.setVolume(_currentVolume));
        await _runOnMainThread(() => _audioPlayer.resume());
      } catch (e) {
        // Silently fail if resume fails
      }
    }
  }

  @override
  void dispose() {
    // Cancel the completion subscription and timer
    _completionSubscription?.cancel();
    _completionSubscription = null;
    _completionTimer?.cancel();
    _completionTimer = null;

    if (Platform.isWindows) {
      _runOnMainThread(() async => _audioPlayer.dispose());
    } else {
      _audioPlayer.dispose();
    }
  }

  @override
  void pause() {
    if (Platform.isWindows) {
      _runOnMainThread(() async => _audioPlayer.pause()).catchError((_) {});
    } else {
      try {
        _audioPlayer.pause();
      } catch (e) {
        // Silently fail
      }
    }
  }

  @override
  void resume() {
    if (Platform.isWindows) {
      _runOnMainThread(() async => _audioPlayer.resume()).catchError((_) {});
    } else {
      try {
        _audioPlayer.resume();
      } catch (e) {
        // Silently fail
      }
    }
  }

  @override
  void setLoop(bool loop) {
    if (Platform.isWindows) {
      _runOnMainThread(() async {
        _wasLooping = loop;
        await _audioPlayer.setReleaseMode(loop ? ReleaseMode.loop : ReleaseMode.release);

        // Only clear looping sound path when explicitly disabling loop
        if (!loop) {
          _loopingSoundPath = null;
        }
      }).catchError((_) {});
    } else {
      try {
        _wasLooping = loop;
        _audioPlayer.setReleaseMode(loop ? ReleaseMode.loop : ReleaseMode.release);

        // Only clear looping sound path when explicitly disabling loop
        if (!loop) {
          _loopingSoundPath = null;
        }
      } catch (e) {
        // Silently fail
      }
    }
  }

  @override
  void setVolume(double volume) {
    if (Platform.isWindows) {
      _runOnMainThread(() async {
        _currentVolume = volume;
        await _audioPlayer.setVolume(volume);
      }).catchError((_) {});
    } else {
      try {
        _currentVolume = volume;
        _audioPlayer.setVolume(volume);
      } catch (e) {
        // Silently fail
      }
    }
  }

  // Getter for current volume
  double get currentVolume => _currentVolume;

  @override
  void stop() {
    // Cancel any completion timer
    _completionTimer?.cancel();
    _completionTimer = null;

    if (Platform.isWindows) {
      _runOnMainThread(() async {
        await _audioPlayer.stop();
        _wasLooping = false;
        _loopingSoundPath = null;
        _isPlayingOneTimeSound = false;
      }).catchError((_) {});
    } else {
      try {
        _audioPlayer.stop();
        _wasLooping = false;
        _loopingSoundPath = null;
        _isPlayingOneTimeSound = false;
      } catch (e) {
        // Silently fail
      }
    }
  }
}

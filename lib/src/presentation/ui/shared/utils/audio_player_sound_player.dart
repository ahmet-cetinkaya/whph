import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';
import 'package:whph/corePackages/acore/sounds/abstraction/sound_player/i_sound_player.dart';

class AudioPlayerSoundPlayer implements ISoundPlayer {
  final AudioPlayer _audioPlayer = AudioPlayer();
  final Map<String, Uint8List> _soundCache = {};
  bool _isInitialized = false;

  // Loop context preservation
  bool _wasLooping = false;
  String? _loopingSoundPath;
  bool _isPlayingOneTimeSound = false;
  bool _listenerSetup = false;

  Future<void> _ensureInitialized(String path, {bool requestAudioFocus = true}) async {
    if (!_soundCache.containsKey(path)) {
      _soundCache[path] = (await rootBundle.load(path)).buffer.asUint8List();
    }

    if (!_isInitialized) {
      // Configure audio context based on whether we want audio focus
      await _audioPlayer.setAudioContext(
        AudioContext(
          android: AudioContextAndroid(
            audioFocus: requestAudioFocus ? AndroidAudioFocus.gainTransientMayDuck : AndroidAudioFocus.none,
          ),
        ),
      );

      await _audioPlayer.setSourceBytes(_soundCache[path]!);
      await _audioPlayer.setVolume(0);
      await _audioPlayer.stop();
      _isInitialized = true;
    }

    // Setup completion listener once
    if (!_listenerSetup) {
      _audioPlayer.onPlayerComplete.listen((event) {
        if (_isPlayingOneTimeSound && _loopingSoundPath != null) {
          _resumeLoopingSound();
        }
      });
      _listenerSetup = true;
    }
  }

  @override
  void play(String path, {bool requestAudioFocus = true}) async {
    await _ensureInitialized(path, requestAudioFocus: requestAudioFocus);

    // Check if we're currently looping and this is a different sound
    final wasCurrentlyLooping = _wasLooping && _loopingSoundPath != null && _loopingSoundPath != path;

    if (wasCurrentlyLooping && requestAudioFocus) {
      // We're interrupting a looping sound with a one-time sound
      _isPlayingOneTimeSound = true;

      // Stop current looping sound
      await _audioPlayer.stop();

      // Play the one-time sound
      await _audioPlayer.setSourceBytes(_soundCache[path]!);
      await _audioPlayer.setReleaseMode(ReleaseMode.release); // One-time play
      await _audioPlayer.setVolume(1);
      await _audioPlayer.resume();
    } else {
      // Normal play - either first sound or replacing current sound
      await _audioPlayer.stop();
      await _audioPlayer.setSourceBytes(_soundCache[path]!);
      await _audioPlayer.setVolume(1);
      await _audioPlayer.resume();

      // Set looping sound path if we're in loop mode
      if (_wasLooping) {
        _loopingSoundPath = path;
      }
    }
  }

  Future<void> _resumeLoopingSound() async {
    if (_loopingSoundPath != null && _wasLooping && _isPlayingOneTimeSound) {
      _isPlayingOneTimeSound = false;

      // Resume the looping sound
      await _audioPlayer.setSourceBytes(_soundCache[_loopingSoundPath!]!);
      await _audioPlayer.setReleaseMode(ReleaseMode.loop);
      await _audioPlayer.setVolume(1);
      await _audioPlayer.resume();
    }
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
  }

  @override
  void pause() {
    _audioPlayer.pause();
  }

  @override
  void resume() {
    _audioPlayer.resume();
  }

  @override
  void setLoop(bool loop) {
    _wasLooping = loop;
    _audioPlayer.setReleaseMode(loop ? ReleaseMode.loop : ReleaseMode.release);

    // Only clear looping sound path when explicitly disabling loop
    if (!loop) {
      _loopingSoundPath = null;
    }
  }

  @override
  void setVolume(double volume) {
    _audioPlayer.setVolume(volume);
  }

  @override
  void stop() {
    _audioPlayer.stop();
    _wasLooping = false;
    _loopingSoundPath = null;
    _isPlayingOneTimeSound = false;
  }
}

import 'dart:io';
import 'dart:typed_data';
import 'package:audioplayers/audioplayers.dart';
import 'package:whph/core/acore/sounds/abstraction/sound_player/i_sound_player.dart';

class AudioPlayerSoundPlayer implements ISoundPlayer {
  final AudioPlayer _audioPlayer = AudioPlayer();
  final Map<String, Uint8List> _soundCache = {};
  bool _isInitialized = false;

  Future<void> _ensureInitialized(String path) async {
    if (!_soundCache.containsKey(path)) {
      _soundCache[path] = await File(path).readAsBytes();
    }

    if (!_isInitialized) {
      await _audioPlayer.setSourceBytes(_soundCache[path]!);
      await _audioPlayer.setVolume(0);
      await _audioPlayer.stop();
      _isInitialized = true;
    }
  }

  @override
  Future<void> play(String path) async {
    await _ensureInitialized(path);
    await _audioPlayer.stop();
    await _audioPlayer.setSourceBytes(_soundCache[path]!);
    await _audioPlayer.setVolume(1);
    await _audioPlayer.resume();
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
    _audioPlayer.setReleaseMode(loop ? ReleaseMode.loop : ReleaseMode.release);
  }

  @override
  void setVolume(double volume) {
    _audioPlayer.setVolume(volume);
  }

  @override
  void stop() {
    _audioPlayer.stop();
  }
}

import 'dart:io';
import 'dart:typed_data';
import 'package:audioplayers/audioplayers.dart';
import 'package:whph/core/acore/sounds/abstraction/sound_player/i_sound_player.dart';

class AudioPlayerSoundPlayer implements ISoundPlayer {
  final AudioPlayer _audioPlayer = AudioPlayer();

  @override
  void dispose() {
    _audioPlayer.dispose();
  }

  @override
  void pause() {
    _audioPlayer.pause();
  }

  @override
  Future<void> play(String path) async {
    stop();

    Uint8List bytes = await File(path).readAsBytes();
    _audioPlayer.setSourceBytes(bytes);
    _audioPlayer.setVolume(1);
    _audioPlayer.resume();
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

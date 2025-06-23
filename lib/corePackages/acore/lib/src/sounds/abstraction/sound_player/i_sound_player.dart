abstract class ISoundPlayer {
  void play(String path, {bool requestAudioFocus = true});
  void stop();
  void pause();
  void resume();
  void setVolume(double volume);
  void setLoop(bool loop);
  void dispose();
}

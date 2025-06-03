abstract class ISoundPlayer {
  void play(String path);
  void stop();
  void pause();
  void resume();
  void setVolume(double volume);
  void setLoop(bool loop);
  void dispose();
}

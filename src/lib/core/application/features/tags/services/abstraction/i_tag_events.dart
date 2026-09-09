abstract class ITagEvents {
  void notifyTagCreated(String tagId);
  void notifyTagUpdated(String tagId);
  void notifyTagDeleted(String tagId);
}

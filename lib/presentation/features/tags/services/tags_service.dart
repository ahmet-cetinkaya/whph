import 'package:flutter/foundation.dart';

class TagsService extends ChangeNotifier {
  // Event listeners for tag-related events
  final ValueNotifier<String?> onTagCreated = ValueNotifier<String?>(null);
  final ValueNotifier<String?> onTagUpdated = ValueNotifier<String?>(null);
  final ValueNotifier<String?> onTagDeleted = ValueNotifier<String?>(null);

  void notifyTagCreated(String tagId) {
    onTagCreated.value = tagId;
    onTagCreated.notifyListeners();
  }

  void notifyTagUpdated(String tagId) {
    onTagUpdated.value = tagId;
    onTagUpdated.notifyListeners();
  }

  void notifyTagDeleted(String tagId) {
    onTagDeleted.value = tagId;
    onTagDeleted.notifyListeners();
  }

  @override
  void dispose() {
    onTagCreated.dispose();
    onTagUpdated.dispose();
    onTagDeleted.dispose();
    super.dispose();
  }
}

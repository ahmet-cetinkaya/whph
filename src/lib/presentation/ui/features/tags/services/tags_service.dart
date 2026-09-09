import 'package:flutter/foundation.dart';
import 'package:whph/core/application/features/tags/services/abstraction/i_tag_events.dart';

class TagsService extends ChangeNotifier implements ITagEvents {
  // Event listeners for tag-related events
  final ValueNotifier<String?> onTagCreated = ValueNotifier<String?>(null);
  final ValueNotifier<String?> onTagUpdated = ValueNotifier<String?>(null);
  final ValueNotifier<String?> onTagDeleted = ValueNotifier<String?>(null);

  @override
  void notifyTagCreated(String tagId) {
    onTagCreated.value = tagId;
    onTagCreated.notifyListeners();
  }

  @override
  void notifyTagUpdated(String tagId) {
    onTagUpdated.value = tagId;
    onTagUpdated.notifyListeners();
  }

  @override
  void notifyTagDeleted(String tagId) {
    onTagDeleted.value = tagId;
    onTagDeleted.notifyListeners();
  }

  void notifyRefresh() {
    onTagCreated.value = null;
    onTagUpdated.value = null;
    onTagDeleted.value = null;
    onTagCreated.notifyListeners();
    onTagUpdated.notifyListeners();
    onTagDeleted.notifyListeners();
    notifyListeners();
  }

  @override
  void dispose() {
    onTagCreated.dispose();
    onTagUpdated.dispose();
    onTagDeleted.dispose();
    super.dispose();
  }
}

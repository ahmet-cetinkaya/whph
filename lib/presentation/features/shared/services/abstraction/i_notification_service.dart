abstract class INotificationService {
  Future<void> init();
  Future<void> destroy();

  Future<void> show({
    required String title,
    required String body,
    String? payload,
  });

  Future<void> clearAll();
}

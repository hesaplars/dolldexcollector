class PushNotificationService {
  const PushNotificationService();

  Stream<Object> get foregroundMessages => const Stream.empty();

  Future<void> requestPermission() async {}

  Future<String?> getToken() async {
    return null;
  }

  Future<void> syncToken({
    required String platform,
  }) async {}

  Future<void> subscribeToUserTopic(String userId) async {}

  Future<void> unsubscribeFromUserTopic(String userId) async {}
}

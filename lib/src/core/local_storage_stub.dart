class LocalStorage {
  static Future<void> setString(String key, String value) async {}
  static Future<String?> getString(String key) async => null;
  
  static Future<void> setStringList(String key, List<String> value) async {}
  static Future<List<String>> getStringList(String key) async => const [];
}

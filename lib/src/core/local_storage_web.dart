import 'dart:html' as html;
import 'dart:convert';

class LocalStorage {
  static Future<void> setString(String key, String value) async {
    html.window.localStorage[key] = value;
  }

  static Future<String?> getString(String key) async {
    return html.window.localStorage[key];
  }

  static Future<void> setStringList(String key, List<String> value) async {
    html.window.localStorage[key] = jsonEncode(value);
  }

  static Future<List<String>> getStringList(String key) async {
    final raw = html.window.localStorage[key];
    if (raw == null) return const [];
    try {
      final decoded = jsonDecode(raw) as List;
      return decoded.map((e) => e.toString()).toList();
    } catch (_) {
      return const [];
    }
  }
}

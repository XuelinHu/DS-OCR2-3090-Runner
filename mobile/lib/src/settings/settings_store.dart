import 'package:shared_preferences/shared_preferences.dart';

class SettingsStore {
  static const _baseUrlKey = 'api_base_url';
  static const defaultBaseUrl = 'http://10.0.2.2:8000';

  Future<String> loadBaseUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_baseUrlKey) ?? defaultBaseUrl;
  }

  Future<void> saveBaseUrl(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_baseUrlKey, value.trim());
  }
}

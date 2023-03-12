import 'package:shared_preferences/shared_preferences.dart';

class SharedPreferencesHelper {
  /// 検索履歴を保存
  static Future<void> setSearchHistories(List<String> searchHistories) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
        SharedPreferencesHelperKey.searchHistories.toString(), searchHistories);
  }

  /// 検索履歴を取得
  static Future<List<String>> getSearchHistories() async {
    List<String> searchHistories = [];
    final prefs = await SharedPreferences.getInstance();
    searchHistories = prefs.getStringList(
            SharedPreferencesHelperKey.searchHistories.toString()) ??
        [];

    return searchHistories;
  }

  static Future<void> setSeekPosition({
    required String url,
    required Duration duration,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final stringDuration = duration.toString();
    final setPosition = '$url,$stringDuration';
    await prefs.setString(
        SharedPreferencesHelperKey.seekPosition.toString(), setPosition);
  }

  static Future<String> getSeekPosition() async {
    final prefs = await SharedPreferences.getInstance();
    final seekPosition =
        prefs.getString(SharedPreferencesHelperKey.seekPosition.toString()) ??
            '';
    return seekPosition;
  }
}

enum SharedPreferencesHelperKey {
  searchHistories,
  seekPosition,
}

import 'package:shared_preferences/shared_preferences.dart';

class Localstorage {
  static const String Favorites = "favorites";
  static const String WatchLater = "WatchLater";
  static const String Subscribe = "Subscribe";
  static const String IsTodayNotify = "IsTodayNotify";
  static const String ImagesUrls = "ImagesUrls";
  static const String ShowsCacheMemo = "ShowsCacheMemo";
  static const String LastVerifyDate = "LastVerifyDate";
  static const String isAdmin = "isAdmin";

  static Future<void> setData(String key, dynamic value) async {
    final prefs = await SharedPreferences.getInstance();
    if (value is String) {
      await prefs.setString(key, value);
    } else if (value is int) {
      await prefs.setInt(key, value);
    } else if (value is double) {
      await prefs.setDouble(key, value);
    } else if (value is bool) {
      await prefs.setBool(key, value);
    } else if (value is List<String>) {
      await prefs.setStringList(key, value);
    } else {
      throw Exception("Unsupported data type");
    }
  }

  static Future<void> addFavorite(String item) async {
    final prefs = await SharedPreferences.getInstance();
    final favorites = prefs.getStringList(Favorites) ?? [];
    if (!favorites.contains(item)) {
      favorites.add(item);
      await prefs.setStringList(Favorites, favorites);
    }
  }

  static Future<void> removeFavorite(String item) async {
    final prefs = await SharedPreferences.getInstance();
    final favorites = prefs.getStringList(Favorites) ?? [];
    if (favorites.contains(item)) {
      favorites.remove(item);
      await prefs.setStringList(Favorites, favorites);
    }
  }

  static Future<bool> isFavorite(String item) async {
    final prefs = await SharedPreferences.getInstance();
    final favorites = prefs.getStringList(Favorites) ?? [];
    return favorites.contains(item);
  }

  static Future<void> addWatchLater(String item) async {
    final prefs = await SharedPreferences.getInstance();
    final favorites = prefs.getStringList(WatchLater) ?? [];
    if (!favorites.contains(item)) {
      favorites.add(item);
      await prefs.setStringList(WatchLater, favorites);
    }
  }

  static Future<void> removeWatchLater(String item) async {
    final prefs = await SharedPreferences.getInstance();
    final favorites = prefs.getStringList(WatchLater) ?? [];
    if (favorites.contains(item)) {
      favorites.remove(item);
      await prefs.setStringList(WatchLater, favorites);
    }
  }

  static Future<bool> isWatchLater(String item) async {
    final prefs = await SharedPreferences.getInstance();
    final favorites = prefs.getStringList(WatchLater) ?? [];
    return favorites.contains(item);
  }

  static Future<void> addSubscribe(String item) async {
    final prefs = await SharedPreferences.getInstance();
    final favorites = prefs.getStringList(Subscribe) ?? [];
    if (!favorites.contains(item)) {
      favorites.add(item);
      await prefs.setStringList(Subscribe, favorites);
    }
  }

  static Future<void> removeSubscribe(String item) async {
    final prefs = await SharedPreferences.getInstance();
    final favorites = prefs.getStringList(Subscribe) ?? [];
    if (favorites.contains(item)) {
      favorites.remove(item);
      await prefs.setStringList(Subscribe, favorites);
    }
  }

  static Future<bool> isSubscribe(String item) async {
    final prefs = await SharedPreferences.getInstance();
    final favorites = prefs.getStringList(Subscribe) ?? [];
    return favorites.contains(item);
  }

    static Future<void> addIsTodayNotify(String item) async {
    final prefs = await SharedPreferences.getInstance();
    final favorites = prefs.getStringList(IsTodayNotify) ?? [];
    if (!favorites.contains(item)) {
      favorites.add(item);
      await prefs.setStringList(IsTodayNotify, favorites);
    }
  }
  static Future<bool> isTodayNotify(String item) async {
    final prefs = await SharedPreferences.getInstance();
    final favorites = prefs.getStringList(IsTodayNotify) ?? [];
    return favorites.contains(item);
  }

  static Future<void> clearData(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(key);
  }

  static Future<void> updateData(String key, dynamic newValue) async {
    final prefs = await SharedPreferences.getInstance();
    final existingValue = prefs.get(key);

    if (existingValue == null) {
      await setData(key, newValue);
      return;
    }

    if (existingValue is String && newValue is String) {
      await prefs.setString(key, existingValue + newValue);
    } else if (existingValue is int && newValue is int) {
      await prefs.setInt(key, existingValue + newValue);
    } else if (existingValue is double && newValue is double) {
      await prefs.setDouble(key, existingValue + newValue);
    } else if (existingValue is List<String> && newValue is List<String>) {
      await prefs.setStringList(key, existingValue + newValue);
    } else {
      throw Exception("Unsupported or mismatched data type for update");
    }
  }

  static Future<dynamic> getData(String key) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.get(key);
  }
}

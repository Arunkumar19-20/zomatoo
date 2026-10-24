// lib/services/search_client_id.dart
// A random id made on this device and sent with searches so the server can count distinct searchers.
// It is not tied to an account, email or device identifier, and the server never stores it as is.

import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';

class SearchClientId {
  static const _key = 'search_client_id';
  static String? _cached;

  /// The stored id, created on first use. Falls back to a per-run id if storage is unavailable.
  static Future<String> get() async {
    if (_cached != null) return _cached!;
    try {
      final prefs = await SharedPreferences.getInstance();
      var id = prefs.getString(_key);
      if (id == null || id.length < 16) {
        id = _random();
        await prefs.setString(_key, id);
      }
      return _cached = id;
    } catch (_) {
      return _cached = _random();
    }
  }

  static String _random() {
    final r = Random.secure();
    return List.generate(16, (_) => r.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
  }

  /// For tests.
  static void reset() => _cached = null;
}

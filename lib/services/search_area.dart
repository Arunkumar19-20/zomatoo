// lib/services/search_area.dart
// The city the customer says they are in, so "what is rising" can show what is popular near them. Optional, off until they set it.
//
// Only the city name goes to the server, with searches and the trending request; never an address or a position. It is not sent when the
// customer has turned search counting off (see SearchPrivacy).

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'search_privacy.dart';

class SearchArea {
  static const _key = 'search_area';
  static const maxLength = 80;

  /// What the customer entered, or null.
  static final ValueNotifier<String?> areaNotifier = ValueNotifier(null);

  /// What to send: the chosen city, unless search counting is off.
  static String? get current => SearchPrivacy.optedOut ? null : areaNotifier.value;

  static Future<void> load() async {
    try {
      areaNotifier.value = clean((await SharedPreferences.getInstance()).getString(_key));
    } catch (_) {
      // no stored choice
    }
  }

  /// Saves the city, or forgets it when [city] is empty.
  static Future<void> set(String? city) async {
    final value = clean(city);
    areaNotifier.value = value;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (value == null) {
        await prefs.remove(_key);
      } else {
        await prefs.setString(_key, value);
      }
    } catch (_) {
      // the choice still holds for this run
    }
  }

  /// Trimmed, single spaces, at most [maxLength] characters; null when nothing is left.
  static String? clean(String? city) {
    if (city == null) return null;
    final c = city.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (c.isEmpty) return null;
    return c.length > maxLength ? c.substring(0, maxLength) : c;
  }

  /// For tests.
  static void reset([String? area]) => areaNotifier.value = area;
}

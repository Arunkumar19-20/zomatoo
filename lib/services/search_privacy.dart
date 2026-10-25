// lib/services/search_privacy.dart
// Whether this device lets the server count its searches. On by default; the customer can turn it off in their profile.
//
// Off means: the app sends "Do Not Track" with searches (the server then records nothing about them), reports no taps, and attaches no search
// to cart adds, so no order is ever linked to a search. Trending and search itself work the same either way.

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SearchPrivacy {
  static const _optOutKey = 'search_log_opt_out';
  static const _noticeKey = 'search_notice_seen';

  /// True when the customer has turned search counting off.
  static final ValueNotifier<bool> optedOutNotifier = ValueNotifier(false);

  /// True once the customer has seen (and dismissed) the first-use notice.
  static final ValueNotifier<bool> noticeSeenNotifier = ValueNotifier(false);

  static bool get optedOut => optedOutNotifier.value;
  static bool get noticeSeen => noticeSeenNotifier.value;

  /// Reads the saved choice. Safe to call when storage is unavailable: the defaults then apply.
  static Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      optedOutNotifier.value = prefs.getBool(_optOutKey) ?? false;
      noticeSeenNotifier.value = prefs.getBool(_noticeKey) ?? false;
    } catch (_) {
      // keep the defaults
    }
  }

  static Future<void> setOptedOut(bool value) async {
    optedOutNotifier.value = value;
    try {
      (await SharedPreferences.getInstance()).setBool(_optOutKey, value);
    } catch (_) {
      // the choice still holds for this run
    }
  }

  static Future<void> markNoticeSeen() async {
    noticeSeenNotifier.value = true;
    try {
      (await SharedPreferences.getInstance()).setBool(_noticeKey, true);
    } catch (_) {}
  }

  /// For tests.
  static void reset({bool optedOut = false, bool noticeSeen = false}) {
    optedOutNotifier.value = optedOut;
    noticeSeenNotifier.value = noticeSeen;
  }
}

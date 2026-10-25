import 'package:flutter/material.dart';
import '../../services/search_privacy.dart';
import '../../theme/app_theme.dart';

/// The plain-language promise, shown wherever the choice is offered.
const String kSearchPrivacyText =
    'We count searches anonymously: what was typed and whether a dish was tapped or ordered, never who you are. It shows restaurants what customers are craving.';

/// The switch in the profile: counting searches on or off. Off, nothing about the customer's searches is recorded and no order is linked to a search.
class SearchPrivacyTile extends StatelessWidget {
  const SearchPrivacyTile({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: SearchPrivacy.optedOutNotifier,
      builder: (context, optedOut, _) => SwitchListTile.adaptive(
        key: const ValueKey('search-privacy-switch'),
        contentPadding: const EdgeInsets.symmetric(horizontal: 4),
        activeColor: AppTheme.chipOrange,
        secondary: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(10)),
          child: Icon(Icons.shield_outlined, color: Colors.green.shade700, size: 20),
        ),
        title: const Text('Help improve search', style: TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(optedOut ? 'Off: nothing about your searches is recorded.' : kSearchPrivacyText, style: const TextStyle(fontSize: 12)),
        value: !optedOut,
        onChanged: (on) => SearchPrivacy.setOptedOut(!on),
      ),
    );
  }
}

/// Shown once above the first search results: says what is counted and lets the customer turn it off or dismiss it.
class SearchPrivacyNotice extends StatelessWidget {
  const SearchPrivacyNotice({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: SearchPrivacy.optedOutNotifier,
      builder: (context, optedOut, _) => ValueListenableBuilder<bool>(
        valueListenable: SearchPrivacy.noticeSeenNotifier,
        builder: (context, seen, _) {
          if (seen || optedOut) return const SizedBox.shrink();
          return Container(
            key: const ValueKey('search-privacy-notice'),
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.fromLTRB(12, 10, 8, 4),
            decoration: BoxDecoration(color: const Color(0xFFF1F8E9), borderRadius: BorderRadius.circular(12), border: Border.all(color: AppTheme.freshGreen.withValues(alpha: 0.5))),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Icon(Icons.shield_outlined, size: 16, color: Colors.green.shade700),
                  const SizedBox(width: 8),
                  const Expanded(child: Text(kSearchPrivacyText, style: TextStyle(fontSize: 12, height: 1.3))),
                ]),
                Align(
                  alignment: Alignment.centerRight,
                  child: Wrap(spacing: 4, children: [
                    TextButton(
                      key: const ValueKey('search-privacy-off'),
                      onPressed: () async {
                        await SearchPrivacy.setOptedOut(true);
                        await SearchPrivacy.markNoticeSeen();
                      },
                      child: const Text('Turn off'),
                    ),
                    TextButton(key: const ValueKey('search-privacy-ok'), onPressed: SearchPrivacy.markNoticeSeen, child: const Text('Got it')),
                  ]),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

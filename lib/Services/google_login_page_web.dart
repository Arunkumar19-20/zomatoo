// Web implementation — uses dart:html to open a popup on a direct user click
// so Chrome doesn't block it and window.opener is set correctly.
// This file is only compiled on web (conditional import in google_login_page.dart).

// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'google_login_page.dart';

Widget buildMobileWebView(BuildContext context, String loginUrl, String role) {
  return _WebPopupLoginPage(loginUrl: loginUrl, role: role);
}

class _WebPopupLoginPage extends StatefulWidget {
  final String loginUrl;
  final String role;
  const _WebPopupLoginPage({required this.loginUrl, required this.role});

  @override
  State<_WebPopupLoginPage> createState() => _WebPopupLoginPageState();
}

class _WebPopupLoginPageState extends State<_WebPopupLoginPage> {
  html.WindowBase? _popup;
  StreamSubscription<html.MessageEvent>? _messageSub;
  Timer? _pollTimer;
  bool _resolved = false;
  bool _waitingForPopup = false;

  @override
  void initState() {
    super.initState();
    // Listen for postMessage from the OAuth success page.
    _messageSub = html.window.onMessage.listen(_onMessage);
  }

  void _onMessage(html.MessageEvent event) {
    if (_resolved) return;
    try {
      final data = jsonDecode(event.data.toString()) as Map<String, dynamic>;
      final token = data['token']?.toString();
      if (token != null && token.isNotEmpty) {
        _resolveWithData(token, data['email']?.toString() ?? '', data['role']?.toString() ?? widget.role);
      }
    } catch (_) {
      // Not our message — ignore
    }
  }

  /// Poll localStorage every 500 ms for the token written by the backend
  /// success page. This handles the case where Chrome opens the OAuth tab
  /// without window.opener (so postMessage never arrives).
  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (_resolved) {
        _pollTimer?.cancel();
        return;
      }
      // Check localStorage for token written by backend success HTML.
      final raw = html.window.localStorage['oauth_token'];
      if (raw != null && raw.isNotEmpty) {
        // Clear immediately so it doesn't linger.
        html.window.localStorage.remove('oauth_token');
        html.window.localStorage.remove('oauth_email');
        html.window.localStorage.remove('oauth_role');
        try {
          final decoded = jsonDecode(raw) as Map<String, dynamic>;
          final token = decoded['token']?.toString();
          if (token != null && token.isNotEmpty) {
            _resolveWithData(
              token,
              decoded['email']?.toString() ?? '',
              decoded['role']?.toString() ?? widget.role,
            );
            return;
          }
        } catch (_) {
          // raw might be a plain token string (legacy)
          _resolveWithData(raw, '', widget.role);
          return;
        }
      }

      // Also check if the popup itself is now at localhost (callback done)
      // and try to read the token from its localStorage.
      try {
        final popup = _popup;
        if (popup != null) {
          // If popup navigated back to localhost, its localStorage is same-origin
          final popupToken = html.window.localStorage['oauth_token'];
          if (popupToken != null && popupToken.isNotEmpty) {
            html.window.localStorage.remove('oauth_token');
            _resolveWithData(popupToken, '', widget.role);
          }
        }
      } catch (_) {}
    });
  }

  void _resolveWithData(String token, String email, String role) {
    if (_resolved) return;
    _resolved = true;
    _pollTimer?.cancel();
    _messageSub?.cancel();
    _popup?.close();
    if (mounted) {
      Navigator.of(context).pop(GoogleLoginResult(
        token: token,
        email: email,
        role: role,
      ));
    }
  }

  /// Opens (or re-opens) the Google OAuth popup.
  ///
  /// IMPORTANT: This MUST be called from a direct user button tap.
  /// Chrome blocks window.open() if it is not triggered by a click event —
  /// it opens a tab instead, which has no window.opener, so postMessage fails.
  void _openPopup() {
    _popup?.close();

    final screenWidth = html.window.screen?.width ?? 1200;
    final screenHeight = html.window.screen?.height ?? 800;
    const popupWidth = 520;
    const popupHeight = 660;
    final left = ((screenWidth - popupWidth) / 2).round();
    final top = ((screenHeight - popupHeight) / 2).round();

    _popup = html.window.open(
      widget.loginUrl,
      'google_oauth_signin',
      'width=$popupWidth,height=$popupHeight,left=$left,top=$top,'
      'resizable=yes,scrollbars=yes',
    );

    if (mounted) setState(() => _waitingForPopup = true);

    // Start polling localStorage in case postMessage doesn't work.
    _startPolling();
  }

  @override
  void dispose() {
    _messageSub?.cancel();
    _pollTimer?.cancel();
    if (!_resolved) _popup?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Sign in with Google',
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.black87),
          onPressed: () {
            _messageSub?.cancel();
            _popup?.close();
            Navigator.of(context).pop(null);
          },
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(36.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Google icon
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: const Color(0xFFE95322).withOpacity(0.08),
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Text('G', style: TextStyle(
                    fontSize: 38,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFE95322),
                  )),
                ),
              ),
              const SizedBox(height: 28),

              if (!_waitingForPopup) ...[
                // ── FIRST STATE: not yet clicked ──
                const Text(
                  'Ready to sign in',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Tap the button below to open the\nGoogle sign-in window.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 32),
                // ── THIS IS THE BUTTON THAT MUST BE CLICKED ──
                // Chrome only allows popup when opened from a direct user click
                ElevatedButton.icon(
                  onPressed: _openPopup, // ← called on direct tap = popup works!
                  icon: const Text('G', style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: Colors.white,
                  )),
                  label: const Text(
                    'Open Google Sign-In',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE95322),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 32, vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                    elevation: 2,
                  ),
                ),
              ] else ...[
                // ── SECOND STATE: popup is open, waiting for auth ──
                const Text(
                  'Complete sign-in in the popup',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Finish signing in with Google in the\npopup window. This page will update\nautomatically.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'If you don\'t see the popup, check for a\n🚫 blocked popup notice in the address bar.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade400,
                  ),
                ),
                const SizedBox(height: 28),
                const SizedBox(
                  width: 32,
                  height: 32,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Color(0xFFE95322),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Waiting for sign-in…',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade500,
                  ),
                ),
                const SizedBox(height: 32),
                OutlinedButton.icon(
                  onPressed: _openPopup, // re-open on direct tap
                  icon: const Icon(Icons.open_in_browser_rounded, size: 18),
                  label: const Text('Re-open Sign-In Popup'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFE95322),
                    side: const BorderSide(color: Color(0xFFE95322)),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 16),
              TextButton(
                onPressed: () {
                  _messageSub?.cancel();
                  _popup?.close();
                  Navigator.of(context).pop(null);
                },
                child: Text(
                  'Cancel',
                  style: TextStyle(color: Colors.grey.shade500),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

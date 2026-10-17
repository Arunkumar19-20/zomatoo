// lib/screens/google_login_page.dart
//
// Backend flow:
//   1. GET /google-login?role=CUSTOMER  -> stores role in session, then
//      redirects to `/oauth2/authorization/google`
//   2. Google handles auth, redirects back via Spring Security's OAuth2 callback
//   3. CustomOAuth2SuccessHandler writes raw JSON: { "token": "...", "email": "...", "role": "..." }
//
// On mobile (Android/iOS) we run this in a WebViewWidget and read the final body.
// On web, webview_flutter is NOT supported, so we launch the URL in the browser tab.

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'api_client.dart';

// webview_flutter is mobile-only — conditional import
import 'google_login_page_mobile.dart'
    if (dart.library.html) 'google_login_page_web.dart';

class GoogleLoginResult {
  final String token;
  final String email;
  final String role;

  GoogleLoginResult({required this.token, required this.email, required this.role});
}

class GoogleLoginPage extends StatefulWidget {
  /// Role to send to the backend: e.g. "CUSTOMER", "OWNER", "DELIVERY".
  final String role;

  const GoogleLoginPage({super.key, required this.role});

  @override
  State<GoogleLoginPage> createState() => _GoogleLoginPageState();
}

class _GoogleLoginPageState extends State<GoogleLoginPage> {
  bool _loading = false;

  String get _loginUrl =>
      '${ApiClient.baseUrl}/google-login?role=${Uri.encodeComponent(widget.role)}';

  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      // On web: open in browser, show a waiting UI
      _openInBrowser();
    }
  }

  Future<void> _openInBrowser() async {
    setState(() => _loading = true);
    final uri = Uri.parse(_loginUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open browser for Google Sign-In')),
        );
        Navigator.of(context).pop(null);
      }
    }
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      // Web: show a simple waiting screen — auth happens in the browser tab
      return Scaffold(
        appBar: AppBar(title: const Text('Sign in with Google')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_loading) const CircularProgressIndicator(),
                const SizedBox(height: 24),
                const Text(
                  'A browser window has been opened for Google Sign-In.\n\nComplete sign-in there and return to the app.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 32),
                ElevatedButton.icon(
                  onPressed: _openInBrowser,
                  icon: const Icon(Icons.open_in_browser),
                  label: const Text('Re-open Sign-In'),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(null),
                  child: const Text('Cancel'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Mobile: use the native WebView implementation
    return buildMobileWebView(context, _loginUrl, widget.role);
  }
}

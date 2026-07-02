// lib/screens/google_login_page.dart
//
// This is the actual "redirect page" for your backend's login flow.
//
// Backend flow recap:
//   1. GET /google-login?role=CUSTOMER  -> stores role in session, then
//      does `redirect:/oauth2/authorization/google`
//   2. Google handles auth, redirects back into Spring Security's OAuth2
//      callback endpoint
//   3. CustomOAuth2SuccessHandler writes a raw JSON body to the response:
//        { "token": "...", "email": "...", "role": "..." }
//
// Because step 3 is not a normal `myapp://redirect` deep link — it's a
// plain JSON page rendered inside the browser flow — the cleanest way to
// consume it from Flutter is to run the whole flow inside a WebView and
// read the final page's body once it looks like JSON.

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../core/api_client.dart';

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
  late final WebViewController _controller;
  bool _resolved = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();

    final loginUrl =
        '${ApiClient.baseUrl}/google-login?role=${Uri.encodeComponent(widget.role)}';

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) => setState(() => _loading = true),
          onPageFinished: (url) async {
            setState(() => _loading = false);
            await _tryExtractResult();
          },
          onWebResourceError: (error) {
            if (!_resolved) {
              _finish(error: 'Failed to load login page: ${error.description}');
            }
          },
        ),
      )
      ..loadRequest(Uri.parse(loginUrl));
  }

  /// After every page load, check whether the body is now the raw JSON
  /// written by CustomOAuth2SuccessHandler. If so, parse it and return.
  Future<void> _tryExtractResult() async {
    if (_resolved) return;

    try {
      final raw = await _controller.runJavaScriptReturningResult(
        'document.body.innerText',
      );

      // runJavaScriptReturningResult returns a JSON-encoded string on most
      // platforms (quoted). Strip surrounding quotes/escapes if present.
      String bodyText = raw.toString();
      if (bodyText.startsWith('"') && bodyText.endsWith('"')) {
        bodyText = jsonDecode(bodyText) as String;
      }

      if (bodyText.contains('"token"') && bodyText.contains('"email"')) {
        final decoded = jsonDecode(bodyText) as Map<String, dynamic>;
        if (decoded['token'] != null) {
          _finish(
            result: GoogleLoginResult(
              token: decoded['token'],
              email: decoded['email'] ?? '',
              role: decoded['role'] ?? widget.role,
            ),
          );
        }
      } else if (bodyText.startsWith('ERROR:')) {
        _finish(error: bodyText);
      }
    } catch (_) {
      // Page not ready / not JSON yet (still mid-OAuth-redirect) — ignore
      // and wait for the next onPageFinished call.
    }
  }

  void _finish({GoogleLoginResult? result, String? error}) {
    if (_resolved) return;
    _resolved = true;
    if (result != null) {
      Navigator.of(context).pop(result);
    } else {
      Navigator.of(context).pop(null);
      if (error != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sign in with Google')),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_loading) const LinearProgressIndicator(),
        ],
      ),
    );
  }
}

// Mobile implementation — uses webview_flutter (Android / iOS only)
//
// The backend flow:
//   GET /google-login?role=CUSTOMER
//     → sets role in session, redirects to /oauth2/authorization/google
//     → Google OAuth
//     → Spring's /login/oauth2/code/google callback
//     → CustomOAuth2SuccessHandler writes: {"token":"...","email":"...","role":"..."}
//
// We detect the token JSON by monitoring the URL: as soon as the WebView
// lands on localhost (after the OAuth round-trip), we read document.body.innerText.
// We also retry on every onPageFinished until we get a valid token.

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'google_login_page.dart';
import 'api_client.dart';

Widget buildMobileWebView(BuildContext context, String loginUrl, String role) {
  return _MobileWebViewPage(loginUrl: loginUrl, role: role);
}

class _MobileWebViewPage extends StatefulWidget {
  final String loginUrl;
  final String role;
  const _MobileWebViewPage({required this.loginUrl, required this.role});

  @override
  State<_MobileWebViewPage> createState() => _MobileWebViewPageState();
}

class _MobileWebViewPageState extends State<_MobileWebViewPage> {
  late final WebViewController _controller;
  bool _resolved = false;
  bool _loading = true;
  String _currentUrl = '';

  // The base URL of our backend — used to detect when OAuth has completed
  // and we're back on our own server.
  String get _backendHost => Uri.parse(ApiClient.baseUrl).host;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      // DO NOT override the user agent — Google blocks OAuth in WebViews
      // that advertise a custom/bot user agent. Leave it as the system default
      // so Google treats it as a real browser window.
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (url) {
            if (mounted) setState(() => _loading = true);
            _currentUrl = url;
            // Try to extract token immediately from URL (e.g. auth.html?token=...)
            _tryExtractResult(url);
          },
          onPageFinished: (url) async {
            if (mounted) setState(() => _loading = false);
            _currentUrl = url;
            // Retry extraction in case URL check above missed it (body fallback).
            await _tryExtractResult(url);
          },
          onNavigationRequest: (request) {
            // Allow all navigation so the OAuth flow can complete.
            return NavigationDecision.navigate;
          },
          onWebResourceError: (error) {
            // Only report errors that are NOT from third-party ad/tracking scripts.
            if (!_resolved &&
                (error.errorCode == -1 || error.errorCode == -2) &&
                (_currentUrl.contains(_backendHost) ||
                    _currentUrl.isEmpty)) {
              // Serious network error on our own server — abort
              _finish(error: 'Connection error: ${error.description}');
            }
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.loginUrl));
  }

  /// Called every time a page starts or finishes loading.
  /// Primary path: detect the /auth.html?token=... redirect and extract
  /// the token directly from the URL — no need to parse the HTML body.
  /// Fallback: if the page body contains raw JSON, parse that too.
  Future<void> _tryExtractResult(String url) async {
    if (_resolved) return;

    final uri = Uri.tryParse(url);
    if (uri == null) return;

    final onBackend = uri.host == _backendHost ||
        uri.host == 'localhost' ||
        uri.host == '10.0.2.2' ||
        uri.host == '127.0.0.1';

    if (!onBackend) return;

    // ── PRIMARY: token is in the URL query params (auth.html redirect) ──
    final token = uri.queryParameters['token'];
    final email = uri.queryParameters['email'] ?? '';
    final role  = uri.queryParameters['role']  ?? widget.role;

    if (token != null && token.isNotEmpty) {
      _finish(result: GoogleLoginResult(token: token, email: email, role: role));
      return;
    }

    // ── FALLBACK: read token from page body (legacy raw-JSON response) ──
    await Future.delayed(const Duration(milliseconds: 400));
    if (_resolved) return;

    try {
      final raw = await _controller.runJavaScriptReturningResult(r'''
        (function() {
          try {
            var el = document.getElementById('token-data');
            var text = el ? el.innerText || el.textContent : '';
            if (!text || !text.trim()) {
              text = document.body ? (document.body.innerText || document.body.textContent) : '';
            }
            text = text.trim();
            var parsed = JSON.parse(text);
            if (parsed && parsed.token && parsed.email) {
              return JSON.stringify(parsed);
            }
          } catch(e) {}
          return '';
        })()
      ''');

      String jsonStr = raw.toString().trim();
      if (jsonStr.startsWith('"') && jsonStr.endsWith('"')) {
        try { jsonStr = jsonDecode(jsonStr) as String; } catch (_) {}
      }

      if (jsonStr.isNotEmpty && jsonStr.startsWith('{')) {
        final decoded = jsonDecode(jsonStr) as Map<String, dynamic>;
        final t = decoded['token']?.toString();
        final e = decoded['email']?.toString() ?? '';
        final r = decoded['role']?.toString() ?? widget.role;
        if (t != null && t.isNotEmpty) {
          _finish(result: GoogleLoginResult(token: t, email: e, role: r));
        }
      }
    } catch (_) {
      // Page body not ready — will retry on next onPageFinished
    }
  }

  void _finish({GoogleLoginResult? result, String? error}) {
    if (_resolved) return;
    _resolved = true;
    if (!mounted) return;
    if (result != null) {
      Navigator.of(context).pop(result);
    } else {
      Navigator.of(context).pop(null);
      if (error != null) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error)));
      }
    }
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
          onPressed: () => _finish(),
        ),
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_loading)
            const LinearProgressIndicator(minHeight: 3),
        ],
      ),
    );
  }
}

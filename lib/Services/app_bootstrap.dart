import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'session_provider.dart';
import 'web_oauth_storage_stub.dart'
    if (dart.library.html) 'web_oauth_storage_web.dart';

/// Prepares the shared session, restores tokens, and captures OAuth redirects if on Web.
Future<SessionProvider> bootstrapApp({String? defaultRole}) async {
  WidgetsFlutterBinding.ensureInitialized();

  final session = SessionProvider();
  if (defaultRole != null) {
    session.setSelectedRole(defaultRole);
  }

  // Web: check if auth.html wrote a token to localStorage after the
  // direct-tab OAuth redirect returned the user to '/'.
  if (kIsWeb) {
    try {
      final raw = getOAuthToken();
      if (raw != null && raw.isNotEmpty) {
        clearOAuthToken();
        final decoded = jsonDecode(raw) as Map<String, dynamic>;
        final token = decoded['token']?.toString();
        final email = decoded['email']?.toString() ?? '';
        final role = decoded['role']?.toString() ?? (defaultRole ?? 'CUSTOMER');
        if (token != null && token.isNotEmpty) {
          await session.login(token, email, role);
        }
      }
    } catch (_) {}
  }

  await session.restoreSession();

  // If session has no logged-in user yet and a default role was specified, apply it
  if (defaultRole != null && session.user == null) {
    session.setSelectedRole(defaultRole);
  }

  return session;
}

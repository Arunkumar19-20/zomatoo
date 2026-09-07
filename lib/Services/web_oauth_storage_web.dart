// lib/Services/web_oauth_storage_web.dart
// Web implementation — reads/clears the token written by auth.html.

// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

String? getOAuthToken() {
  return html.window.localStorage['oauth_token'];
}

void clearOAuthToken() {
  html.window.localStorage.remove('oauth_token');
  html.window.localStorage.remove('oauth_email');
  html.window.localStorage.remove('oauth_role');
}

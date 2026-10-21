import 'dart:convert';
import 'package:crypto/crypto.dart';

class JwtHelper {
  static const String defaultSecret =
      'change-this-to-a-secure-random-string-at-least-256-bits-long';

  static String _base64Url(String input) {
    return base64Url.encode(utf8.encode(input)).replaceAll('=', '');
  }

  /// Generates a valid HS256 JWT accepted by the Spring Boot backend's JwtFilter.
  static String generateBackendToken(String email, String role,
      {String secret = defaultSecret}) {
    final header = _base64Url(jsonEncode({'alg': 'HS256', 'typ': 'JWT'}));
    final nowSeconds = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final expSeconds = nowSeconds + (86400 * 30); // 30 days validity

    final payload = _base64Url(jsonEncode({
      'sub': email,
      'role': role.toUpperCase(),
      'iat': nowSeconds,
      'exp': expSeconds,
    }));

    final dataToSign = '$header.$payload';
    final hmac = Hmac(sha256, utf8.encode(secret));
    final digest = hmac.convert(utf8.encode(dataToSign));
    final signature = base64Url.encode(digest.bytes).replaceAll('=', '');

    return '$dataToSign.$signature';
  }
}

import 'package:flutter_test/flutter_test.dart';
import 'package:tomatoo/services/api_client.dart';

void main() {
  group('ApiClient Configuration Tests', () {
    test('baseUrl returns platform default when API_BASE_URL is not set', () {
      final url = ApiClient.baseUrl;
      expect(url, isNotEmpty);
      expect(url.startsWith('http://'), isTrue);
      expect(url.contains(':8080'), isTrue);
    });

    test('ApiClient singleton exposes dio and rawDio with configured baseUrl', () {
      final client = ApiClient.instance;
      expect(client.dio, isNotNull);
      expect(client.rawDio, isNotNull);
      expect(client.dio.options.baseUrl, equals(ApiClient.baseUrl));
      expect(client.rawDio.options.baseUrl, equals(ApiClient.baseUrl));
    });
  });
}

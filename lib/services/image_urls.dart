// lib/services/image_urls.dart
// Dish photos uploaded by owners are stored as a path on our own server ("/uploads/dishes/<id>.jpg"); photos from elsewhere are full links.
// Screens need a full link to load either one.

import 'api_client.dart';

/// A link the app can load: paths on our server get the API address in front, everything else is returned as it is.
String? resolveImageUrl(String? url, {String? base}) {
  if (url == null || url.isEmpty) return url;
  if (!url.startsWith('/') || url.startsWith('//')) return url;
  final root = (base ?? ApiClient.baseUrl).replaceAll(RegExp(r'/+$'), '');
  return '$root$url';
}

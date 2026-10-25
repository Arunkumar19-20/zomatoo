// lib/services/dish_photo_picker.dart
// Choosing a photo for a dish. Behind a small interface so forms and tests do not depend on the device's gallery.

import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';

/// The server refuses photos above this size.
const int kMaxDishPhotoBytes = 2 * 1024 * 1024;

class PickedPhoto {
  final Uint8List bytes;
  final String name;
  const PickedPhoto({required this.bytes, required this.name});

  bool get tooLarge => bytes.length > kMaxDishPhotoBytes;
}

abstract class DishPhotoPicker {
  /// The photo the owner chose, or null if they backed out.
  Future<PickedPhoto?> pick();
}

class GalleryDishPhotoPicker implements DishPhotoPicker {
  const GalleryDishPhotoPicker();

  @override
  Future<PickedPhoto?> pick() async {
    // scaled down and recompressed on the device so an ordinary phone photo fits under the limit
    final file = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1600, maxHeight: 1600, imageQuality: 85);
    if (file == null) return null;
    return PickedPhoto(bytes: await file.readAsBytes(), name: file.name);
  }
}

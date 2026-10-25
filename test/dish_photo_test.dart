import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tomatoo/models/dish_search_models.dart';
import 'package:tomatoo/models/models.dart' as api;
import 'package:tomatoo/services/api_client.dart';
import 'package:tomatoo/services/dish_photo_picker.dart';
import 'package:tomatoo/services/image_urls.dart';
import 'package:tomatoo/services/menu_service.dart';
import 'package:tomatoo/widgets/owner/add_dish_dialog.dart';

import 'fakes/fake_dish_search.dart';

/// A real 1x1 PNG so the preview can decode it.
final Uint8List _png = base64Decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==');

class _FakePicker implements DishPhotoPicker {
  PickedPhoto? next;
  Object? failure;
  int calls = 0;
  @override
  Future<PickedPhoto?> pick() async {
    calls++;
    if (failure != null) throw failure!;
    return next;
  }
}

class _CapturingAdapter implements HttpClientAdapter {
  RequestOptions? seen;
  String reply = '{"id":7,"name":"Pasta","price":200,"imageUrl":"/uploads/dishes/abc.png"}';
  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    seen = options;
    return ResponseBody.fromString(reply, 200, headers: {Headers.contentTypeHeader: [Headers.jsonContentType]});
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  group('resolveImageUrl', () {
    test('puts the API address in front of a path on our server', () {
      expect(resolveImageUrl('/uploads/dishes/a.png', base: 'http://localhost:8080'), 'http://localhost:8080/uploads/dishes/a.png');
      expect(resolveImageUrl('/uploads/dishes/a.png', base: 'http://localhost:8080/'), 'http://localhost:8080/uploads/dishes/a.png', reason: 'no double slash');
    });

    test('leaves full links, empty values and null alone', () {
      expect(resolveImageUrl('https://images.example.com/x.jpg', base: 'http://localhost:8080'), 'https://images.example.com/x.jpg');
      expect(resolveImageUrl('//cdn.example.com/x.jpg', base: 'http://localhost:8080'), '//cdn.example.com/x.jpg');
      expect(resolveImageUrl('', base: 'http://localhost:8080'), '');
      expect(resolveImageUrl(null, base: 'http://localhost:8080'), isNull);
    });

    test('search hits, menu dishes and cart lines come out loadable', () {
      final base = ApiClient.baseUrl;
      final hit = DishHit.fromJson({'itemId': 1, 'name': 'Pasta', 'price': 200, 'veg': true, 'restaurantId': 2, 'imageUrl': '/uploads/dishes/a.png'});
      expect(hit.imageUrl, '$base/uploads/dishes/a.png');
      final dto = api.MenuItemDTO.fromJson({'itemId': 1, 'name': 'Pasta', 'price': 200, 'imageUrl': '/uploads/dishes/a.png'});
      expect(dto.imageUrl, '$base/uploads/dishes/a.png');
      final keep = api.MenuItemDTO.fromJson({'itemId': 1, 'name': 'Pasta', 'price': 200, 'imageUrl': 'https://x.test/p.jpg'});
      expect(keep.imageUrl, 'https://x.test/p.jpg');
    });

    test('an editable menu item keeps the server\'s value and offers a loadable one', () {
      final item = api.MenuItem.fromJson({'id': 1, 'name': 'Pasta', 'price': 200, 'imageUrl': '/uploads/dishes/a.png'});
      expect(item.imageUrl, '/uploads/dishes/a.png', reason: 'sent back as it came, never an absolute link');
      expect(item.displayImageUrl, '${ApiClient.baseUrl}/uploads/dishes/a.png');
      expect(item.toJson()['imageUrl'], '/uploads/dishes/a.png');
    });
  });

  group('MenuService photo calls', () {
    late _CapturingAdapter adapter;
    late HttpClientAdapter original;

    setUp(() {
      adapter = _CapturingAdapter();
      original = ApiClient.instance.dio.httpClientAdapter;
      ApiClient.instance.dio.httpClientAdapter = adapter;
    });
    tearDown(() => ApiClient.instance.dio.httpClientAdapter = original);

    test('uploads the photo as a multipart "file" to the dish and returns the dish', () async {
      final dish = await MenuService().uploadDishImage(7, PickedPhoto(bytes: _png, name: 'pasta.png'));
      expect(adapter.seen!.method, 'POST');
      expect(adapter.seen!.path, '/menu-items/7/image');
      final form = adapter.seen!.data as FormData;
      expect(form.files.single.key, 'file');
      expect(form.files.single.value.filename, 'pasta.png');
      expect(dish.imageUrl, '/uploads/dishes/abc.png');
    });

    test('removes the photo with DELETE', () async {
      adapter.reply = '{"id":7,"name":"Pasta","price":200,"imageUrl":null}';
      final dish = await MenuService().removeDishImage(7);
      expect(adapter.seen!.method, 'DELETE');
      expect(adapter.seen!.path, '/menu-items/7/image');
      expect(dish.imageUrl, isNull);
    });
  });

  group('photo in the add-dish form', () {
    late FakeMenuTagRepository tags;
    late _FakePicker picker;
    NewDishInput? result;

    setUp(() {
      tags = FakeMenuTagRepository();
      picker = _FakePicker();
      result = null;
    });

    Future<void> open(WidgetTester tester) async {
      tester.view.physicalSize = const Size(900, 2200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () async {
                  result = await showAddDishDialog(context, tags: tags, categories: [api.MenuCategory(id: 3, name: 'Mains')], photoPicker: picker);
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
    }

    Future<void> fillAndSave(WidgetTester tester) async {
      await tester.enterText(find.byKey(const ValueKey('dish-name')), 'Honey chili paneer');
      await tester.enterText(find.byKey(const ValueKey('dish-price')), '260');
      await tester.tap(find.byKey(const ValueKey('tag-sweet')));
      await tester.tap(find.byKey(const ValueKey('tag-spicy')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('dish-save')));
      await tester.pumpAndSettle();
    }

    testWidgets('a dish can be saved without a photo', (tester) async {
      await open(tester);
      expect(find.byKey(const ValueKey('dish-photo-empty')), findsOneWidget);
      expect(find.byKey(const ValueKey('dish-photo-remove')), findsNothing);
      await fillAndSave(tester);
      expect(result!.photo, isNull);
    });

    testWidgets('a chosen photo is previewed and handed back with the dish', (tester) async {
      picker.next = PickedPhoto(bytes: _png, name: 'pasta.png');
      await open(tester);
      await tester.tap(find.byKey(const ValueKey('dish-photo-add')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('dish-photo-preview')), findsOneWidget);
      expect(find.text('Change photo'), findsOneWidget);
      await fillAndSave(tester);
      expect(result!.photo!.name, 'pasta.png');
      expect(result!.photo!.bytes, _png);
    });

    testWidgets('the photo can be removed again', (tester) async {
      picker.next = PickedPhoto(bytes: _png, name: 'pasta.png');
      await open(tester);
      await tester.tap(find.byKey(const ValueKey('dish-photo-add')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('dish-photo-remove')));
      await tester.pump();
      expect(find.byKey(const ValueKey('dish-photo-preview')), findsNothing);
      await fillAndSave(tester);
      expect(result!.photo, isNull);
    });

    testWidgets('a photo over 2 MB is refused with a reason, and an earlier choice stays', (tester) async {
      picker.next = PickedPhoto(bytes: _png, name: 'small.png');
      await open(tester);
      await tester.tap(find.byKey(const ValueKey('dish-photo-add')));
      await tester.pumpAndSettle();

      picker.next = PickedPhoto(bytes: Uint8List(kMaxDishPhotoBytes + 1), name: 'huge.jpg');
      await tester.tap(find.byKey(const ValueKey('dish-photo-add')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('dish-photo-error')), findsOneWidget);
      expect(find.textContaining('over 2 MB'), findsOneWidget);
      await fillAndSave(tester);
      expect(result!.photo!.name, 'small.png');
    });

    testWidgets('backing out of the picker changes nothing, and a picker error is explained', (tester) async {
      await open(tester);
      await tester.tap(find.byKey(const ValueKey('dish-photo-add')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('dish-photo-preview')), findsNothing);
      expect(find.byKey(const ValueKey('dish-photo-error')), findsNothing);

      picker.failure = Exception('no access');
      await tester.tap(find.byKey(const ValueKey('dish-photo-add')));
      await tester.pumpAndSettle();
      expect(find.text('Could not open your photos.'), findsOneWidget);
    });
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tomatoo/models/dish_search_models.dart';
import 'package:tomatoo/models/models.dart' as api;
import 'package:tomatoo/widgets/owner/add_dish_dialog.dart';

import 'fakes/fake_dish_search.dart';

void main() {
  late FakeMenuTagRepository tags;
  NewDishInput? result;
  bool closed = false;

  setUp(() {
    tags = FakeMenuTagRepository();
    result = null;
    closed = false;
  });

  Future<void> open(WidgetTester tester, {List<api.MenuCategory>? categories, NewDishInitial? initial}) async {
    tester.view.physicalSize = const Size(900, 2200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () async {
                result = await showAddDishDialog(context, tags: tags, categories: categories ?? [api.MenuCategory(id: 3, name: 'Mains')], initial: initial);
                closed = true;
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

  Future<void> fill(WidgetTester tester) async {
    await tester.enterText(find.byKey(const ValueKey('dish-name')), 'Honey chili paneer');
    await tester.enterText(find.byKey(const ValueKey('dish-price')), '260');
    await tester.enterText(find.byKey(const ValueKey('dish-desc')), 'Crispy paneer in a sticky hot honey glaze');
    await tester.enterText(find.byKey(const ValueKey('dish-ingredients')), 'paneer, honey, chili flakes');
  }

  testWidgets('needs a name, a price and at least two flavor tags', (tester) async {
    await open(tester);
    await tester.tap(find.byKey(const ValueKey('dish-save')));
    await tester.pump();
    expect(find.text('Enter a dish name and a price.'), findsOneWidget);

    await fill(tester);
    await tester.tap(find.byKey(const ValueKey('tag-sweet')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('dish-save')));
    await tester.pump();
    expect(find.textContaining('Pick at least 2 flavor tags'), findsOneWidget);
    expect(closed, isFalse);

    await tester.tap(find.byKey(const ValueKey('tag-spicy')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('dish-save')));
    await tester.pumpAndSettle();

    expect(closed, isTrue);
    expect(result!.name, 'Honey chili paneer');
    expect(result!.price, 260);
    expect(result!.flavorTags.toSet(), {'sweet', 'spicy'});
    expect(result!.categoryId, 3);
    expect(result!.servingTemp, 'HOT');
    expect(result!.spiceLevel, 0);
    expect(result!.isVeg, isTrue);
  });

  testWidgets('suggests tags as the owner types and "Add all" selects them', (tester) async {
    tags.suggestions = const [
      TagSuggestion(tag: 'sweet', label: 'Sweet', confidence: 0.92, reasons: ['mentions "honey"']),
      TagSuggestion(tag: 'crunchy', label: 'Crunchy', confidence: 0.74, reasons: ['mentions "crispy"']),
    ];
    await open(tester);
    expect(find.text('Type a name and we will suggest flavor tags.'), findsOneWidget);

    await fill(tester);
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pump();

    expect(tags.suggestCalls, isNotEmpty);
    expect(find.byKey(const ValueKey('dish-suggestions')), findsOneWidget);
    expect(find.text('Sweet 92%'), findsOneWidget);
    expect(find.text('Crunchy 74%'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('dish-accept-all')));
    await tester.pump();
    expect(find.byKey(const ValueKey('dish-suggestions')), findsNothing, reason: 'accepted suggestions leave the list');

    await tester.tap(find.byKey(const ValueKey('dish-save')));
    await tester.pumpAndSettle();
    expect(result!.flavorTags.toSet(), {'sweet', 'crunchy'});
  });

  testWidgets('tapping one suggestion adds just that tag', (tester) async {
    tags.suggestions = const [TagSuggestion(tag: 'spicy', label: 'Spicy', confidence: 0.8)];
    await open(tester);
    await fill(tester);
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('suggest-spicy')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('tag-sweet')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('dish-save')));
    await tester.pumpAndSettle();
    expect(result!.flavorTags.toSet(), {'spicy', 'sweet'});
  });

  testWidgets('works when the server cannot be reached: built-in tag list, no suggestions', (tester) async {
    tags.vocabularyFails = true;
    await open(tester);
    expect(find.byKey(const ValueKey('tag-smoky')), findsOneWidget, reason: 'fallback vocabulary has all 12 flavors');
    expect(find.byKey(const ValueKey('tag-comfort')), findsOneWidget);
  });

  testWidgets('spice, temperature and mood are captured', (tester) async {
    await open(tester);
    await fill(tester);
    await tester.enterText(find.byKey(const ValueKey('dish-mood')), 'sharing');
    await tester.tap(find.text('Cold'));
    await tester.pump();
    final slider = tester.widget<Slider>(find.byKey(const ValueKey('dish-spice')));
    slider.onChanged!(3);
    await tester.pump();
    await tester.tap(find.text('Non-veg'));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('tag-sweet')));
    await tester.tap(find.byKey(const ValueKey('tag-spicy')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('dish-save')));
    await tester.pumpAndSettle();
    expect(result!.spiceLevel, 3);
    expect(result!.servingTemp, 'COLD');
    expect(result!.mood, 'sharing');
    expect(result!.isVeg, isFalse);
  });

  testWidgets('an Insights suggestion prefills the name, description and flavors, and the owner only has to add a price', (tester) async {
    await open(tester, initial: const NewDishInitial(name: 'Kimchi Carbonara', description: 'Our take on Kimchi Carbonara.', flavorTags: ['sweet', 'crunchy']));
    expect(find.widgetWithText(TextField, 'Kimchi Carbonara'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Our take on Kimchi Carbonara.'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('dish-save')));
    await tester.pump();
    expect(find.text('Enter a dish name and a price.'), findsOneWidget, reason: 'the price is never guessed');

    await tester.enterText(find.byKey(const ValueKey('dish-price')), '420');
    await tester.tap(find.byKey(const ValueKey('dish-save')));
    await tester.pumpAndSettle();
    expect(result?.name, 'Kimchi Carbonara');
    expect(result?.price, 420);
    expect(result?.flavorTags.toSet(), {'sweet', 'crunchy'});
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:tomatoo/main.dart';

void main() {
  testWidgets('App smoke test - splash screen renders', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MyApp());

    // Verify that the logo wordmark is rendered.
    expect(find.text('Cravey'), findsOneWidget);
    expect(find.text('Satisfy Your Desires'), findsOneWidget);
  });
}

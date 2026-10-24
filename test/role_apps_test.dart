import 'package:flutter_test/flutter_test.dart';
import 'package:tomatoo/main_customer.dart';
import 'package:tomatoo/main_restaurant.dart';
import 'package:tomatoo/main_delivery.dart';
import 'package:tomatoo/main_admin.dart';

void main() {
  testWidgets('Customer App renders customer splash', (WidgetTester tester) async {
    await tester.pumpWidget(const CraveyCustomerApp());
    expect(find.text('Cravey'), findsOneWidget);
    expect(find.text('Satisfy Your Desires'), findsOneWidget);
  });

  testWidgets('Restaurant App renders partner splash', (WidgetTester tester) async {
    await tester.pumpWidget(const CraveyRestaurantApp());
    expect(find.text('Cravey Partner'), findsOneWidget);
    expect(find.text('Kitchen Queue & Menu Manager'), findsOneWidget);
  });

  testWidgets('Delivery App renders rider splash', (WidgetTester tester) async {
    await tester.pumpWidget(const CraveyDeliveryApp());
    expect(find.text('Cravey Rider'), findsOneWidget);
    expect(find.text('Live Dispatches & Trip Earnings'), findsOneWidget);
  });

  testWidgets('Admin App renders admin splash', (WidgetTester tester) async {
    await tester.pumpWidget(const CraveyAdminApp());
    expect(find.text('Cravey Admin'), findsOneWidget);
    expect(find.text('Platform Operations & Fleet Control'), findsOneWidget);
  });
}

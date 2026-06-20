import 'package:flutter_test/flutter_test.dart';

import 'package:api_6005cmd/app/smart_travel_app.dart';

void main() {
  testWidgets('loads Smart Travel Planner shell', (WidgetTester tester) async {
    await tester.pumpWidget(const SmartTravelApp());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Smart Travel Planner'), findsWidgets);
    expect(find.text('Login'), findsWidgets);
  });
}

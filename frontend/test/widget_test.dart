import 'package:flutter_test/flutter_test.dart';
import 'package:eb_wireman_app/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const EbWiremanApp());
    expect(find.text('Hi Mathavan 👋'), findsWidgets);
  });
}

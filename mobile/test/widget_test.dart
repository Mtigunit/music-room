import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/main.dart';

void main() {
  testWidgets('MyApp shows Music Room text', (tester) async {
    await tester.pumpWidget(const MyApp());

    expect(find.text('Music Room'), findsOneWidget);
  });
}

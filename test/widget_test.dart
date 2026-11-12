import 'package:flutter_test/flutter_test.dart';
import 'package:fogoff/main.dart';

void main() {
  testWidgets('DefogMind app smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const DefogMindRootApp());
    expect(find.byType(DefogMindRootApp), findsOneWidget);
  });
}

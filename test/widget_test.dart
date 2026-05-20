// Kavach — Basic smoke test
// Tests that the app starts without crashing.

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_app/main.dart';

void main() {
  testWidgets('Kavach app launches without crashing',
      (WidgetTester tester) async {
    // ✅ FIXED: MyApp → KavachApp (correct class name from main.dart)
    // Wrapped in ProviderScope as required by Riverpod
    await tester.pumpWidget(
      const ProviderScope(
        child: KavachApp(),
      ),
    );

    // Verify the app renders the Kavach title
    expect(find.text('KAVACH'), findsWidgets);
  });
}

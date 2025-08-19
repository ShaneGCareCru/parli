// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';

import 'package:parli/main.dart';

void main() {
  testWidgets('PTT Screen smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MyApp());

    // Verify that PTT screen loads correctly
    expect(find.text('Parli - Voice Translator'), findsOneWidget);
    expect(find.text('Translation Mode'), findsOneWidget);
    expect(find.text('Hold to Speak'), findsOneWidget);
    expect(find.text('English'), findsAtLeastNWidgets(1));
    expect(find.text('中文'), findsAtLeastNWidgets(1));
  });
}

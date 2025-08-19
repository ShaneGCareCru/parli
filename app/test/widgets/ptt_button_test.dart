import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parli/widgets/ptt_button.dart';

void main() {
  group('PTTButton Widget Tests', () {
    late List<PTTEvent> capturedEvents;

    setUp(() {
      capturedEvents = [];
    });

    void onEvent(PTTEvent event) {
      capturedEvents.add(event);
    }

    testWidgets('should render button with label and icon', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PTTButton(
              label: 'Test',
              onEvent: onEvent,
              icon: Icons.mic,
            ),
          ),
        ),
      );

      expect(find.text('Test'), findsOneWidget);
      expect(find.byIcon(Icons.mic), findsOneWidget);
    });

    testWidgets('should trigger press and release events on tap', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PTTButton(
              label: 'Test',
              onEvent: onEvent,
            ),
          ),
        ),
      );

      final buttonFinder = find.byType(GestureDetector);
      
      final gesture = await tester.startGesture(tester.getCenter(buttonFinder));
      await tester.pumpAndSettle();
      
      expect(capturedEvents, contains(PTTEvent.press));
      
      await gesture.up();
      await tester.pumpAndSettle();
      
      expect(capturedEvents, contains(PTTEvent.release));
    });

    testWidgets('should not trigger events when disabled', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PTTButton(
              label: 'Test',
              onEvent: onEvent,
              isEnabled: false,
            ),
          ),
        ),
      );

      final buttonFinder = find.byType(GestureDetector);
      
      await tester.tap(buttonFinder);
      await tester.pumpAndSettle();
      
      expect(capturedEvents, isEmpty);
    });

    testWidgets('should show different colors for enabled and disabled states', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                PTTButton(
                  key: const Key('enabled'),
                  label: 'Enabled',
                  onEvent: onEvent,
                  isEnabled: true,
                  primaryColor: Colors.blue,
                  disabledColor: Colors.grey,
                ),
                PTTButton(
                  key: const Key('disabled'),
                  label: 'Disabled',
                  onEvent: onEvent,
                  isEnabled: false,
                  primaryColor: Colors.blue,
                  disabledColor: Colors.grey,
                ),
              ],
            ),
          ),
        ),
      );

      final enabledButton = tester.widget<Container>(
        find.descendant(
          of: find.byKey(const Key('enabled')),
          matching: find.byType(Container),
        ).first,
      );
      
      final disabledButton = tester.widget<Container>(
        find.descendant(
          of: find.byKey(const Key('disabled')),
          matching: find.byType(Container),
        ).first,
      );

      final enabledDecoration = enabledButton.decoration as BoxDecoration;
      final disabledDecoration = disabledButton.decoration as BoxDecoration;

      expect(enabledDecoration.color, Colors.blue);
      expect(disabledDecoration.color, Colors.grey);
    });

    testWidgets('should scale animation on press', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PTTButton(
              label: 'Test',
              onEvent: onEvent,
            ),
          ),
        ),
      );

      final buttonFinder = find.byType(GestureDetector);
      
      final gesture = await tester.startGesture(tester.getCenter(buttonFinder));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 110));
      
      final transformWidget = tester.widget<Transform>(
        find.descendant(
          of: find.byType(PTTButton),
          matching: find.byType(Transform),
        ),
      );
      
      expect(transformWidget.transform.getMaxScaleOnAxis(), lessThan(1.0));
      
      await gesture.up();
    });
  });
}
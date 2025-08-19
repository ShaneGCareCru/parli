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

    testWidgets('should have visual press feedback', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PTTButton(
              label: 'Test',
              onEvent: onEvent,
              primaryColor: Colors.blue,
            ),
          ),
        ),
      );

      final buttonFinder = find.byType(GestureDetector);
      
      // Check initial button color
      var containerWidget = tester.widget<Container>(
        find.descendant(
          of: find.byType(PTTButton),
          matching: find.byType(Container),
        ),
      );
      var decoration = containerWidget.decoration as BoxDecoration;
      expect(decoration.color, Colors.blue);
      
      // Start gesture and check color change
      final gesture = await tester.startGesture(tester.getCenter(buttonFinder));
      await tester.pump();
      
      // Verify press event was triggered
      expect(capturedEvents, contains(PTTEvent.press));
      
      // Check pressed button color (should be dimmed)
      containerWidget = tester.widget<Container>(
        find.descendant(
          of: find.byType(PTTButton),
          matching: find.byType(Container),
        ),
      );
      decoration = containerWidget.decoration as BoxDecoration;
      expect(decoration.color, Colors.blue.withValues(alpha: 0.8));
      
      await gesture.up();
      await tester.pump();
      
      // Verify release event was triggered
      expect(capturedEvents, contains(PTTEvent.release));
    });
    
    testWidgets('should trigger hold event after threshold duration', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PTTButton(
              label: 'Test',
              onEvent: onEvent,
              holdThreshold: const Duration(milliseconds: 300),
            ),
          ),
        ),
      );

      final buttonFinder = find.byType(GestureDetector);
      
      final gesture = await tester.startGesture(tester.getCenter(buttonFinder));
      await tester.pump();
      
      expect(capturedEvents, contains(PTTEvent.press));
      expect(capturedEvents, isNot(contains(PTTEvent.hold)));
      
      await tester.pump(const Duration(milliseconds: 350));
      
      expect(capturedEvents, contains(PTTEvent.hold));
      
      await gesture.up();
      await tester.pumpAndSettle();
      
      expect(capturedEvents, contains(PTTEvent.release));
    });
  });
}
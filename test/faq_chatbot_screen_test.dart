import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/screens/faq_chatbot_screen.dart';

void main() {
  group('FaqChatbotScreen UI & Responsive Tests', () {
    Widget buildTestWidget({double width = 390.0, double height = 800.0}) {
      return MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(size: Size(width, height)),
          child: const SizedBox(
            width: double.infinity,
            height: double.infinity,
            child: FaqChatbotScreen(),
          ),
        ),
      );
    }

    testWidgets('Renders initial bot greeting and suggested questions', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('FitLoop Assistant'), findsOneWidget);
      expect(find.textContaining("Hi! I'm the FitLoop Assistant"), findsOneWidget);
      expect(find.text('How do I scan food?'), findsOneWidget);
      expect(find.text('How do I generate a workout?'), findsOneWidget);
    });

    testWidgets('Tapping a suggested question chip sends message and displays answer', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Tap suggestion chip
      final chipFinder = find.widgetWithText(ActionChip, 'How do I scan food?');
      expect(chipFinder, findsOneWidget);
      await tester.tap(chipFinder);
      await tester.pump(); // Start typing indicator / state
      await tester.pump(const Duration(milliseconds: 300)); // Complete response delay
      await tester.pumpAndSettle();

      // Check that user bubble appeared
      expect(find.text('How do I scan food?'), findsWidgets);
      // Check that bot response appeared with answer
      expect(find.textContaining('Tap the center "Scan" button'), findsOneWidget);
    });

    testWidgets('Typing a question and tapping send provides matching FAQ answer', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      final inputFinder = find.byType(TextField);
      expect(inputFinder, findsOneWidget);

      await tester.enterText(inputFinder, 'Where is my data stored?');
      await tester.tap(find.byIcon(Icons.send_rounded));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();

      expect(find.text('Where is my data stored?'), findsWidgets);
      expect(find.textContaining('Firebase Firestore'), findsOneWidget);
    });

    testWidgets('Medical query displays safety notice styling and disclaimer', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      final inputFinder = find.byType(TextField);
      await tester.enterText(inputFinder, 'Can I stop medication?');
      await tester.tap(find.byIcon(Icons.send_rounded));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();

      expect(find.textContaining('Important Health Notice'), findsOneWidget);
      expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
    });

    // Responsive Tests
    for (final width in [320.0, 360.0, 390.0, 412.0]) {
      testWidgets('Renders without overflow on width ${width}px', (tester) async {
        tester.view.physicalSize = Size(width * 2, 800 * 2);
        tester.view.devicePixelRatio = 2.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(buildTestWidget(width: width));
        await tester.pumpAndSettle();

        // Ask a question
        final chipFinder = find.widgetWithText(ActionChip, 'How do I scan food?');
        expect(chipFinder, findsOneWidget);
        await tester.tap(chipFinder);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
      });
    }
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/screens/exercise_library_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget buildTestableWidget(Widget child, {Size size = const Size(390, 844), double bottomInset = 0}) {
    return MediaQuery(
      data: MediaQueryData(
        size: size,
        viewInsets: EdgeInsets.only(bottom: bottomInset),
      ),
      child: MaterialApp(
        home: child,
      ),
    );
  }

  group('Exercise Library Category Chips & Search Tests', () {
    testWidgets('Renders all required category chips', (tester) async {
      await tester.pumpWidget(
        buildTestableWidget(const ExerciseLibraryScreen()),
      );
      await tester.pump();

      expect(find.text('Exercise Library'), findsOneWidget);
      expect(find.text('All'), findsOneWidget);
      expect(find.text('Chest'), findsOneWidget);
      expect(find.text('Back'), findsOneWidget);
      expect(find.text('Legs'), findsOneWidget);
      expect(find.text('Arms'), findsOneWidget);
      expect(find.text('Core'), findsOneWidget);
      expect(find.text('Cardio'), findsOneWidget);
      expect(find.text('Shoulders'), findsOneWidget);
    });

    testWidgets('Tapping category chips switches selection without crash', (tester) async {
      await tester.pumpWidget(
        buildTestableWidget(const ExerciseLibraryScreen()),
      );
      await tester.pump();

      // Tap Core
      await tester.tap(find.text('Core'));
      await tester.pump();

      // Tap Arms
      await tester.tap(find.text('Arms'));
      await tester.pump();

      // Tap Legs
      await tester.tap(find.text('Legs'));
      await tester.pump();

      // Tap Back
      await tester.tap(find.text('Back'));
      await tester.pump();

      // Tap Chest
      await tester.tap(find.text('Chest'));
      await tester.pump();

      // Tap All
      await tester.tap(find.text('All'));
      await tester.pump();
    });

    testWidgets('Search input accepts queries (air bike, cardio, bicep, squat, abs)', (tester) async {
      await tester.pumpWidget(
        buildTestableWidget(const ExerciseLibraryScreen()),
      );
      await tester.pump();

      final searchField = find.byType(TextField);
      expect(searchField, findsOneWidget);

      for (final query in ['air bike', 'cardio', 'bicep', 'squat', 'abs']) {
        await tester.enterText(searchField, query);
        await tester.pump();
        expect(find.text(query), findsOneWidget);
      }
    });
  });

  group('Exercise Library Keyboard Overflow Tests (320px, 360px, 390px)', () {
    final testWidths = [320.0, 360.0, 390.0];

    for (final width in testWidths) {
      testWidgets('No RenderFlex overflow with keyboard open (bottomInset=320) on ${width}px width', (tester) async {
        tester.view.physicalSize = Size(width, 700);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          buildTestableWidget(
            const ExerciseLibraryScreen(),
            size: Size(width, 700),
            bottomInset: 320.0, // Simulate open on-screen virtual keyboard
          ),
        );
        await tester.pump();

        // Check search field is still interactive
        await tester.enterText(find.byType(TextField), 'squat');
        await tester.pump();

        // Verify no overflow exception was thrown
        expect(tester.takeException(), isNull);
      });
    }
  });
}

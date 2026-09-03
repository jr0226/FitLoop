import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/widgets/diet/food_delete_dialog.dart';

void main() {
  testWidgets('Delete confirmation dialog shows meal name and Cancel does not delete', (WidgetTester tester) async {
    bool? dialogResult;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                dialogResult = await showFoodDeleteConfirmationDialog(
                  context,
                  foodName: "Nasi Lemak Ayam Goreng",
                );
              },
              child: const Text("Open Dialog"),
            ),
          ),
        ),
      ),
    );

    // Tap to open dialog
    await tester.tap(find.text("Open Dialog"));
    await tester.pumpAndSettle();

    // Verify dialog contents
    expect(find.text("Delete meal?"), findsOneWidget);
    expect(find.text("This will permanently remove:"), findsOneWidget);
    expect(find.text("Nasi Lemak Ayam Goreng"), findsOneWidget);
    expect(find.text("Cancel"), findsOneWidget);
    expect(find.text("Delete"), findsOneWidget);

    // Tap Cancel
    await tester.tap(find.text("Cancel"));
    await tester.pumpAndSettle();

    // Dialog should be dismissed with false
    expect(dialogResult, isFalse);
    expect(find.text("Delete meal?"), findsNothing);
  });

  testWidgets('Delete confirmation dialog confirms when Delete is tapped', (WidgetTester tester) async {
    bool? dialogResult;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                dialogResult = await showFoodDeleteConfirmationDialog(
                  context,
                  foodName: "McDonald's French Fries (Large)",
                );
              },
              child: const Text("Open Dialog"),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text("Open Dialog"));
    await tester.pumpAndSettle();

    // Tap Delete button
    await tester.tap(find.text("Delete"));
    await tester.pumpAndSettle();

    expect(dialogResult, isTrue);
    expect(find.text("Delete meal?"), findsNothing);
  });

  testWidgets('Tapping outside dialog barrier does not dismiss it', (WidgetTester tester) async {
    bool? dialogResult;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                dialogResult = await showFoodDeleteConfirmationDialog(
                  context,
                  foodName: "Chicken Rice",
                );
              },
              child: const Text("Open Dialog"),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text("Open Dialog"));
    await tester.pumpAndSettle();

    // Tap top-left corner (outside the dialog)
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    // Dialog should still be open
    expect(find.text("Delete meal?"), findsOneWidget);
    expect(dialogResult, isNull);

    // Dismiss with Cancel to clean up
    await tester.tap(find.text("Cancel"));
    await tester.pumpAndSettle();
  });
}

import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/services/scan_draft_service.dart';

Widget _buildTestDraftCard({
  required ScanDraft draft,
  required VoidCallback onDiscard,
  required VoidCallback onResume,
}) {
  return Container(
    margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.amber.shade50,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: Colors.amber.shade300, width: 1.5),
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.amber.shade200,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.edit_note, size: 14, color: Colors.amber.shade900),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        "PREVIOUS SCAN",
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: Colors.amber.shade900,
                          letterSpacing: 0.5,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              draft.timeAgo,
              style: TextStyle(fontSize: 11, color: Colors.amber.shade900, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: 54,
                height: 54,
                color: Colors.amber.shade100,
                child: const Icon(Icons.fastfood, color: Colors.amber),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    draft.mealName,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "${draft.calories} kcal • P: ${draft.protein}g",
                    style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              flex: 1,
              child: OutlinedButton(
                onPressed: onDiscard,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red.shade700,
                  side: BorderSide(color: Colors.red.shade300),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                ),
                child: const FittedBox(fit: BoxFit.scaleDown, child: Text("Discard")),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 1,
              child: ElevatedButton(
                onPressed: onResume,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                ),
                child: const FittedBox(fit: BoxFit.scaleDown, child: Text("Resume")),
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

void main() {
  final sampleDraft = ScanDraft(
    imageHash: 'hash123',
    imageBytes: Uint8List.fromList([1, 2, 3]),
    analysisData: {'totalCalories': 520, 'totalProteins': 28},
    mealName: "McDonald's French Fries (Large) with Fried Chicken",
    timestamp: DateTime.now().subtract(const Duration(minutes: 5)),
  );

  testWidgets('Resume Previous Scan card renders responsive across 320px, 360px, 390px, 412px with 1.2x font scale', (tester) async {
    const screenWidths = [320.0, 360.0, 390.0, 412.0];

    for (final width in screenWidths) {
      tester.view.physicalSize = Size(width, 700.0);
      tester.view.devicePixelRatio = 1.0;

      bool discardTapped = false;
      bool resumeTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(1.2)),
            child: Scaffold(
              body: SingleChildScrollView(
                child: _buildTestDraftCard(
                  draft: sampleDraft,
                  onDiscard: () => discardTapped = true,
                  onResume: () => resumeTapped = true,
                ),
              ),
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull, reason: "Overflow occurred on width $width");
      expect(find.text("PREVIOUS SCAN"), findsOneWidget);
      expect(find.text("5m ago"), findsOneWidget);
      expect(find.text("Resume"), findsOneWidget);
      expect(find.text("Discard"), findsOneWidget);

      await tester.tap(find.text("Discard"));
      expect(discardTapped, isTrue);

      await tester.tap(find.text("Resume"));
      expect(resumeTapped, isTrue);
    }

    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

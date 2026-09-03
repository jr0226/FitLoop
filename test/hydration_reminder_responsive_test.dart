import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget buildHydrationCard({
    required bool enabled,
    required int intervalHours,
    double textScale = 1.0,
    double screenWidth = 360.0,
  }) {
    return MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(
          size: Size(screenWidth, 800),
          textScaler: TextScaler.linear(textScale),
        ),
        child: Scaffold(
          body: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Colors.grey.shade200),
                ),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.blue.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.water_drop_rounded, color: Colors.blue, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Hydration Reminder',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  enabled
                                      ? "Every $intervalHours hours (8:00 AM - 10:00 PM)"
                                      : "Disabled",
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Switch(
                            activeThumbColor: Colors.teal,
                            value: enabled,
                            onChanged: (_) {},
                          ),
                        ],
                      ),
                    ),
                    if (enabled) ...[
                      const Divider(height: 1),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Interval",
                              style: TextStyle(fontSize: 13, color: Colors.grey.shade700, fontWeight: FontWeight.w500),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [2, 3, 4].map((hours) {
                                final isSelected = intervalHours == hours;
                                return ChoiceChip(
                                  label: Text("Every ${hours}h"),
                                  selected: isSelected,
                                  selectedColor: Colors.blue.shade100,
                                  labelStyle: TextStyle(
                                    fontSize: 11,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                    color: isSelected ? Colors.blue.shade900 : Colors.black87,
                                  ),
                                  onSelected: (_) {},
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  group('Hydration Reminder Layout Responsive Tests', () {
    for (final width in [320.0, 360.0, 390.0, 412.0]) {
      testWidgets('Renders without overflow on width ${width}px (enabled, 2h)', (tester) async {
        tester.view.physicalSize = Size(width, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(buildHydrationCard(enabled: true, intervalHours: 2, screenWidth: width));
        expect(tester.takeException(), isNull);
        expect(find.text('Hydration Reminder'), findsOneWidget);
        expect(find.text('Every 2 hours (8:00 AM - 10:00 PM)'), findsOneWidget);
        expect(find.text('Every 2h'), findsOneWidget);
        expect(find.text('Every 3h'), findsOneWidget);
        expect(find.text('Every 4h'), findsOneWidget);
      });

      testWidgets('Renders without overflow on width ${width}px (enabled, 3h)', (tester) async {
        tester.view.physicalSize = Size(width, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(buildHydrationCard(enabled: true, intervalHours: 3, screenWidth: width));
        expect(tester.takeException(), isNull);
        expect(find.text('Every 3 hours (8:00 AM - 10:00 PM)'), findsOneWidget);
      });

      testWidgets('Renders without overflow on width ${width}px (enabled, 4h)', (tester) async {
        tester.view.physicalSize = Size(width, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(buildHydrationCard(enabled: true, intervalHours: 4, screenWidth: width));
        expect(tester.takeException(), isNull);
        expect(find.text('Every 4 hours (8:00 AM - 10:00 PM)'), findsOneWidget);
      });
    }

    testWidgets('Renders without overflow on narrow width 320px with large text scale 1.5x', (tester) async {
      tester.view.physicalSize = const Size(320.0, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildHydrationCard(
        enabled: true,
        intervalHours: 2,
        screenWidth: 320.0,
        textScale: 1.5,
      ));
      expect(tester.takeException(), isNull);
      expect(find.text('Hydration Reminder'), findsOneWidget);
    });

    testWidgets('Renders without overflow on narrow width 320px with extra large text scale 2.0x', (tester) async {
      tester.view.physicalSize = const Size(320.0, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildHydrationCard(
        enabled: true,
        intervalHours: 2,
        screenWidth: 320.0,
        textScale: 2.0,
      ));
      expect(tester.takeException(), isNull);
      expect(find.text('Hydration Reminder'), findsOneWidget);
    });
  });
}

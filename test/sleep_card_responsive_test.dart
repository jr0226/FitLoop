import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/models/health_models.dart';

Widget _buildMiniTracker(BuildContext context, IconData icon, String title, String value, Color color) {
  final theme = Theme.of(context);
  return Container(
    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
    decoration: BoxDecoration(
      color: theme.cardColor,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: theme.colorScheme.outlineVariant),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 6),
        Text(
          title,
          style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 10, fontWeight: FontWeight.w500),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface),
          ),
        ),
      ],
    ),
  );
}

Widget _buildActivityTrackerRow(HealthSummary summary, int streak, bool isConnected) {
  return Builder(
    builder: (context) {
      return Row(
        children: [
          Expanded(
            child: _buildMiniTracker(
              context,
              Icons.directions_walk_rounded,
              "Steps Today",
              isConnected && summary.todaySteps > 0 ? '${summary.todaySteps}' : '--',
              Colors.orange,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildMiniTracker(
              context,
              Icons.bedtime_rounded,
              "Sleep",
              isConnected && summary.sleepHours > 0 ? summary.formattedSleep : '--',
              Colors.purple,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildMiniTracker(
              context,
              Icons.local_fire_department,
              "Streak",
              "$streak d",
              Colors.deepOrange,
            ),
          ),
        ],
      );
    },
  );
}

void main() {
  final screenWidths = [320.0, 360.0, 390.0, 412.0];
  final testCases = [
    const HealthSummary(status: HealthConnectStatus.connected, sleepHours: 7.5, todaySteps: 8420),
    const HealthSummary(status: HealthConnectStatus.connected, sleepHours: 6.25, todaySteps: 12050),
    const HealthSummary(status: HealthConnectStatus.connected, sleepHours: 0.75, todaySteps: 3000),
    const HealthSummary(status: HealthConnectStatus.connected, sleepHours: 8.0, todaySteps: 9500),
    const HealthSummary(status: HealthConnectStatus.connected, sleepHours: 0.0, todaySteps: 0),
  ];

  for (final width in screenWidths) {
    for (final summary in testCases) {
      testWidgets('Home Sleep Card renders at ${width}px width (${summary.formattedSleep}) without overflow', (tester) async {
        tester.view.physicalSize = Size(width * 2, 800 * 2);
        tester.view.devicePixelRatio = 2.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: _buildActivityTrackerRow(summary, 5, true),
              ),
            ),
          ),
        );

        expect(tester.takeException(), isNull);
        if (summary.sleepHours > 0) {
          expect(find.text(summary.formattedSleep), findsOneWidget);
        } else {
          expect(find.text('--'), findsAtLeastNWidgets(1));
        }
      });
    }
  }
}

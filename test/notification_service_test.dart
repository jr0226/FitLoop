import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_application_1/services/notification_service.dart';

void main() {
  setUpAll(() {
    tz.initializeTimeZones();
  });

  group('NotificationService Deterministic IDs & Constants', () {
    test('notification channel constants are defined properly', () {
      expect(NotificationService.channelId, equals('fitloop_reminders'));
      expect(NotificationService.channelName, equals('FitLoop Reminders'));
    });

    test('deterministic notification ID ranges are distinct and non-overlapping', () {
      // Workout IDs: 1001..1007
      final workoutIds = List.generate(7, (i) => NotificationService.workoutIdBase + (i + 1));
      expect(workoutIds, equals([1001, 1002, 1003, 1004, 1005, 1006, 1007]));

      // Meal IDs: 2001, 2002, 2003
      expect(NotificationService.mealBreakfastId, equals(2001));
      expect(NotificationService.mealLunchId, equals(2002));
      expect(NotificationService.mealDinnerId, equals(2003));

      // Hydration IDs: 3001..3010
      final hydrationIds = List.generate(10, (i) => NotificationService.hydrationIdBase + (i + 1));
      expect(hydrationIds.first, equals(3001));
      expect(hydrationIds.last, equals(3010));

      // Weekly Progress ID: 4001
      expect(NotificationService.weeklyProgressId, equals(4001));

      // Diagnostic Test IDs
      expect(NotificationService.diagnosticTestId, equals(9999));
      expect(NotificationService.diagnosticScheduledId, equals(9998));

      // Verify all ID sets have zero intersection
      final allIds = [
        ...workoutIds,
        NotificationService.mealBreakfastId,
        NotificationService.mealLunchId,
        NotificationService.mealDinnerId,
        ...hydrationIds,
        NotificationService.weeklyProgressId,
        NotificationService.diagnosticTestId,
        NotificationService.diagnosticScheduledId,
      ];
      final uniqueIds = allIds.toSet();
      expect(uniqueIds.length, equals(allIds.length));
    });
  });

  group('NotificationService Timezone Scheduling Calculations', () {
    test('nextInstanceOfTime returns exact hour and minute in the future', () {
      final target = NotificationService.instance.nextInstanceOfTime(14, 30);
      final now = tz.TZDateTime.now(tz.local);

      expect(target.hour, equals(14));
      expect(target.minute, equals(30));
      expect(target.isAfter(now) || target.isAtSameMomentAs(now), isTrue);
    });

    test('nextInstanceOfWeekdayAndTime returns exact weekday, hour, and minute', () {
      for (int day = 1; day <= 7; day++) {
        final target = NotificationService.instance.nextInstanceOfWeekdayAndTime(day, 19, 0);
        final now = tz.TZDateTime.now(tz.local);

        expect(target.weekday, equals(day));
        expect(target.hour, equals(19));
        expect(target.minute, equals(0));
        expect(target.isAfter(now) || target.isAtSameMomentAs(now), isTrue);
      }
    });

    test('Sunday weekly progress reminder targets weekday 7', () {
      final sundayDate = NotificationService.instance.nextInstanceOfWeekdayAndTime(7, 20, 0);
      expect(sundayDate.weekday, equals(DateTime.sunday));
      expect(sundayDate.hour, equals(20));
      expect(sundayDate.minute, equals(0));
    });
  });

  group('NotificationService syncAllReminders payload handling', () {
    test('syncAllReminders does not crash with empty or legacy map when masterEnabled is false', () async {
      await expectLater(
        NotificationService.instance.syncAllReminders({}, masterEnabled: false),
        completes,
      );
    });

    test('syncAllReminders parses complete payload safely without throwing', () async {
      final sampleReminders = {
        'workout': {
          'enabled': false,
          'hour': 18,
          'minute': 45,
          'days': [1, 3, 5],
        },
        'meals': {
          'breakfastEnabled': false,
          'breakfastHour': 8,
          'breakfastMinute': 0,
          'lunchEnabled': false,
          'lunchHour': 12,
          'lunchMinute': 15,
          'dinnerEnabled': false,
          'dinnerHour': 19,
          'dinnerMinute': 30,
        },
        'hydration': {
          'enabled': false,
          'intervalHours': 3,
        },
        'weeklyProgress': {
          'enabled': false,
          'dayOfWeek': 7,
          'hour': 20,
          'minute': 0,
        },
      };

      await expectLater(
        NotificationService.instance.syncAllReminders(sampleReminders, masterEnabled: true),
        completes,
      );
    });

    test('sendImmediateTestNotification and scheduleTestNotification execute safely', () async {
      await expectLater(
        NotificationService.instance.sendImmediateTestNotification(),
        completes,
      );

      await expectLater(
        NotificationService.instance.scheduleTestNotification(secondsFromNow: 60),
        completes,
      );

      final pending = await NotificationService.instance.getPendingNotifications();
      expect(pending, isA<List>());
    });
  });
}

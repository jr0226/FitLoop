import 'package:flutter/material.dart';
import '../../models/workout_models.dart';

class WorkoutStreakHeader extends StatelessWidget {
  final StreakSummary streakSummary;

  const WorkoutStreakHeader({super.key, required this.streakSummary});

  @override
  Widget build(BuildContext context) {
    const daysOfWeek = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    final now = DateTime.now();
    final todayWeekdayIndex = (now.weekday - 1).clamp(0, 6);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: Streak stats + Weekly goal badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Left: Flame icon + Streak text
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.local_fire_department_rounded,
                        color: Colors.orange,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "${streakSummary.currentStreakDays} Day Streak",
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            "Best: ${streakSummary.bestStreakDays} days",
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade500,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 8),

              // Right: Weekly Target Pill
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.teal.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.teal.shade200),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.fitness_center_rounded, color: Colors.teal, size: 14),
                    const SizedBox(width: 5),
                    Text(
                      "${streakSummary.weeklyCompletedDays}/${streakSummary.weeklyGoalDays} Days",
                      style: TextStyle(
                        color: Colors.teal.shade800,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),
          Divider(height: 1, color: Colors.grey.shade100),
          const SizedBox(height: 8),

          // Row 2: Compact 7-Day Dots Indicator
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(7, (index) {
              final isActive = index < streakSummary.pastWeekActiveDays.length &&
                  streakSummary.pastWeekActiveDays[index];
              final isToday = index == todayWeekdayIndex;

              return Column(
                children: [
                  Text(
                    daysOfWeek[index],
                    style: TextStyle(
                      color: isToday ? Colors.teal : Colors.grey.shade500,
                      fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                      fontSize: 10,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: isActive
                          ? Colors.teal
                          : (isToday ? Colors.teal.shade50 : Colors.grey.shade100),
                      shape: BoxShape.circle,
                      border: isToday
                          ? Border.all(color: Colors.teal, width: 1.5)
                          : null,
                    ),
                    child: Center(
                      child: isActive
                          ? const Icon(Icons.check, size: 13, color: Colors.white)
                          : Container(
                              width: 5,
                              height: 5,
                              decoration: BoxDecoration(
                                color: isToday ? Colors.teal : Colors.grey.shade300,
                                shape: BoxShape.circle,
                              ),
                            ),
                    ),
                  ),
                ],
              );
            }),
          ),
        ],
      ),
    );
  }
}

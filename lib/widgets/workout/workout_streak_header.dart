import 'package:flutter/material.dart';
import '../../models/workout_models.dart';

class WorkoutStreakHeader extends StatelessWidget {
  final StreakSummary streakSummary;

  const WorkoutStreakHeader({super.key, required this.streakSummary});

  @override
  Widget build(BuildContext context) {
    const daysOfWeek = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.teal.shade800,
            Colors.teal.shade600,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.teal.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: Streak Badge + Target Summary
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.orangeAccent, width: 1.5),
                      ),
                      child: const Icon(
                        Icons.local_fire_department_rounded,
                        color: Colors.orangeAccent,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Text(
                                '${streakSummary.currentStreakDays}',
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Flexible(
                                child: Text(
                                  'DAYS STREAK',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white70,
                                    letterSpacing: 1.0,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          Text(
                            'Best: ${streakSummary.bestStreakDays} days 🔥',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.teal.shade100,
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
              // Weekly goal count chip
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white24),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.check_circle_outline, color: Colors.white, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      '${streakSummary.weeklyCompletedDays}/${streakSummary.weeklyGoalDays} Days',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),

          // Row 2: 7-Day Mini Calendar Bubbles
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(7, (index) {
              final isActive = index < streakSummary.pastWeekActiveDays.length &&
                  streakSummary.pastWeekActiveDays[index];
              final isToday = index == 4; // Mock today (Friday)

              return Column(
                children: [
                  Text(
                    daysOfWeek[index],
                    style: TextStyle(
                      color: isToday ? Colors.amberAccent : Colors.white70,
                      fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: isActive
                          ? Colors.orangeAccent
                          : Colors.white.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                      border: isToday
                          ? Border.all(color: Colors.amberAccent, width: 2)
                          : null,
                    ),
                    child: Center(
                      child: isActive
                          ? const Icon(Icons.check, size: 18, color: Colors.black87)
                          : Text(
                              '${index + 1}',
                              style: const TextStyle(color: Colors.white60, fontSize: 11),
                            ),
                    ),
                  ),
                ],
              );
            }),
          ),

          const SizedBox(height: 16),

          // Row 3: Linear Weekly Goal Progress Bar
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Weekly Target Progress',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  Text(
                    '${(streakSummary.weeklyProgress * 100).toInt()}%',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: streakSummary.weeklyProgress,
                  minHeight: 7,
                  backgroundColor: Colors.black26,
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.amberAccent),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Row 4: Milestone Badges Strip
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: streakSummary.badges.map((badge) {
                return Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: badge.isUnlocked
                        ? Colors.white.withValues(alpha: 0.2)
                        : Colors.black.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: badge.isUnlocked ? badge.color.withValues(alpha: 0.6) : Colors.white12,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        badge.icon,
                        size: 15,
                        color: badge.isUnlocked ? badge.color : Colors.white38,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        badge.title,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: badge.isUnlocked ? Colors.white : Colors.white38,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

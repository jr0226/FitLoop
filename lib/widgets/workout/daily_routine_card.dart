import 'package:flutter/material.dart';
import '../../models/workout_models.dart';

class DailyRoutineCard extends StatelessWidget {
  final WorkoutRoutine routine;
  final VoidCallback onStart;
  final VoidCallback? onTap;

  const DailyRoutineCard({
    super.key,
    required this.routine,
    required this.onStart,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.teal.shade100, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.teal.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Header: Tag + Category Chip
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Icon(
                            routine.isAiGenerated ? Icons.auto_awesome : Icons.calendar_today_rounded,
                            size: 14,
                            color: routine.isAiGenerated ? Colors.purple : Colors.teal,
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              routine.isAiGenerated ? "RECOMMENDED FOR YOU" : "TODAY'S WORKOUT",
                              style: TextStyle(
                                color: routine.isAiGenerated ? Colors.purple.shade700 : Colors.teal.shade800,
                                fontWeight: FontWeight.w800,
                                fontSize: 11,
                                letterSpacing: 0.8,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      constraints: const BoxConstraints(maxWidth: 140),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.teal.shade50,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        routine.category,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.teal.shade800,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // Routine Title
                Text(
                  routine.title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),

                const SizedBox(height: 8),

                // Metrics Tag Row (Duration • Calories • Level • Movements)
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _buildMetaChip(
                      icon: Icons.timer_outlined,
                      label: "${routine.durationMinutes} min",
                      color: Colors.grey.shade700,
                    ),
                    _buildMetaChip(
                      icon: Icons.local_fire_department_rounded,
                      label: "${routine.estimatedCalories} kcal",
                      color: Colors.orange.shade800,
                    ),
                    _buildMetaChip(
                      icon: Icons.speed_rounded,
                      label: routine.level.displayName,
                      color: routine.level.badgeColor,
                    ),
                    _buildMetaChip(
                      icon: Icons.fitness_center_rounded,
                      label: "${routine.exercises.length} exercises",
                      color: Colors.teal.shade800,
                    ),
                  ],
                ),

                const SizedBox(height: 14),
                Divider(height: 1, color: Colors.grey.shade100),
                const SizedBox(height: 12),

                // Movement preview list (up to 3)
                if (routine.exercises.isNotEmpty) ...[
                  ...routine.exercises.take(3).map((ex) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primary,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                ex.name,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.black87,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text(
                              "${ex.defaultSets} × ${ex.defaultReps}",
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      )),
                  if (routine.exercises.length > 3)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        "+ ${routine.exercises.length - 3} more exercises (Tap to view all)",
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.teal.shade700,
                        ),
                      ),
                    ),
                  const SizedBox(height: 14),
                ],

                // Single Visually Dominant Primary CTA
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: onStart,
                    icon: const Icon(Icons.play_arrow_rounded, size: 22),
                    label: const Text(
                      "Start Workout",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                      foregroundColor: Colors.white,
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMetaChip({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

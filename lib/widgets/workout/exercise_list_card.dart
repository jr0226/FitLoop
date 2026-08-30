import 'package:flutter/material.dart';
import '../../models/workout_models.dart';

class ExerciseListCard extends StatelessWidget {
  final ExerciseModel exercise;
  final VoidCallback onTap;
  final VoidCallback? onAdd;

  const ExerciseListCard({
    super.key,
    required this.exercise,
    required this.onTap,
    this.onAdd,
  });

  IconData _getMuscleIcon(String muscle) {
    switch (muscle.toLowerCase()) {
      case 'chest':
        return Icons.fitness_center;
      case 'back':
        return Icons.accessibility_new_rounded;
      case 'legs':
        return Icons.directions_walk_rounded;
      case 'arms':
        return Icons.sports_handball_rounded;
      case 'core':
        return Icons.crop_square_rounded;
      default:
        return Icons.flash_on_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Muscle / Movement Animated Thumbnail Placeholder
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.teal.shade50,
                      Colors.teal.shade100.withValues(alpha: 0.5),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.teal.shade100),
                ),
                child: Center(
                  child: Icon(
                    _getMuscleIcon(exercise.targetMuscle),
                    color: Colors.teal.shade700,
                    size: 28,
                  ),
                ),
              ),

              const SizedBox(width: 14),

              // Exercise info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      exercise.name,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Target: ${exercise.targetMuscle}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Badges: Equipment + Difficulty Tier
                    Row(
                      children: [
                        // Equipment Badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.handyman_outlined, size: 11, color: Colors.black54),
                              const SizedBox(width: 4),
                              Text(
                                exercise.equipment,
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black87,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),

                        // Difficulty Tier
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: exercise.difficulty.badgeColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: exercise.difficulty.badgeColor.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Text(
                            exercise.difficulty.displayName,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: exercise.difficulty.badgeColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Action Arrow / Add Button
              if (onAdd != null)
                IconButton(
                  icon: const Icon(Icons.add_circle, color: Colors.teal, size: 28),
                  onPressed: onAdd,
                  tooltip: 'Add to workout',
                )
              else
                Icon(Icons.chevron_right, color: Colors.grey.shade400, size: 22),
            ],
          ),
        ),
      ),
    );
  }
}

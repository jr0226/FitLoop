import 'package:flutter/material.dart';
import '../../models/workout_models.dart';

class AiRecommendationBanner extends StatelessWidget {
  final WorkoutRoutine routine;
  final VoidCallback onQuickStart;
  final VoidCallback? onRegenerate;

  const AiRecommendationBanner({
    super.key,
    required this.routine,
    required this.onQuickStart,
    this.onRegenerate,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF1E1B4B), // Deep indigo
            Color(0xFF312E81),
            Color(0xFF4C1D95), // Vibrant purple
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4C1D95).withValues(alpha: 0.35),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Background decorative glow shapes
          Positioned(
            right: -20,
            top: -20,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.purpleAccent.withValues(alpha: 0.15),
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // AI Header badge & match score
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(7),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Colors.purpleAccent, Colors.cyanAccent],
                              ),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.auto_awesome_rounded,
                              color: Colors.black87,
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'AI SUGGESTED FOR YOU',
                                  style: TextStyle(
                                    color: Colors.cyanAccent,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 11,
                                    letterSpacing: 1.1,
                                  ),
                                ),
                                Text(
                                  'Based on recent performance & recovery',
                                  style: TextStyle(color: Colors.white60, fontSize: 10),
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

                    // AI Match Score Tag
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.cyanAccent.withValues(alpha: 0.4)),
                      ),
                      child: Text(
                        '${(routine.aiMatchScore * 100).toInt()}% Match',
                        style: const TextStyle(
                          color: Colors.cyanAccent,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 14),

                // Routine Title
                Text(
                  routine.title,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  routine.subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.white70,
                    height: 1.3,
                  ),
                ),

                const SizedBox(height: 12),

                // Quick stats pill row
                Row(
                  children: [
                    _buildStatPill(Icons.timer_outlined, '${routine.durationMinutes} mins'),
                    const SizedBox(width: 8),
                    _buildStatPill(Icons.local_fire_department, '${routine.estimatedCalories} kcal'),
                    const SizedBox(width: 8),
                    _buildStatPill(Icons.fitness_center, '${routine.exercises.length} movements'),
                  ],
                ),

                const SizedBox(height: 16),

                // Action Bar: Quick Start & AI Regenerate
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 44,
                        child: ElevatedButton.icon(
                          onPressed: onQuickStart,
                          icon: const Icon(Icons.bolt, color: Colors.black87, size: 20),
                          label: const Text(
                            'Quick-Start AI Workout',
                            style: TextStyle(
                              color: Colors.black87,
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.cyanAccent,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (onRegenerate != null) ...[
                      const SizedBox(width: 8),
                      Container(
                        height: 44,
                        width: 44,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white24),
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.refresh_rounded, color: Colors.white, size: 20),
                          onPressed: onRegenerate,
                          tooltip: 'Regenerate suggestion',
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatPill(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: Colors.white70),
          const SizedBox(width: 4),
          Text(
            text,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

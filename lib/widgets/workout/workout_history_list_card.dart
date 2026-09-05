import 'package:flutter/material.dart';
import '../../models/workout_models.dart';

class WorkoutHistoryListCard extends StatefulWidget {
  final WorkoutHistorySession session;

  const WorkoutHistoryListCard({super.key, required this.session});

  @override
  State<WorkoutHistoryListCard> createState() => _WorkoutHistoryListCardState();
}

class _WorkoutHistoryListCardState extends State<WorkoutHistoryListCard> {
  bool _isExpanded = false;

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final difference = now.difference(dt);

    if (difference.inDays == 0) {
      return "Today, ${_pad(dt.hour)}:${_pad(dt.minute)}";
    } else if (difference.inDays == 1) {
      return "Yesterday";
    } else {
      const months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
      return "${months[dt.month - 1]} ${dt.day}, ${dt.year}";
    }
  }

  String _pad(int n) => n.toString().padLeft(2, '0');

  @override
  Widget build(BuildContext context) {
    final s = widget.session;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          children: [
            // Session Header Tile
            InkWell(
              onTap: () => setState(() => _isExpanded = !_isExpanded),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.teal.shade50,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.fitness_center_rounded, color: Colors.teal, size: 18),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              _formatDate(s.date),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.teal.shade800,
                              ),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                "${s.durationMinutes} mins",
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.black87),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Icon(
                              _isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                              color: Colors.grey,
                            ),
                          ],
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // Routine Name + Source Badge
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            s.routineName,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                        if (s.isMerged) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.teal.shade50,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: Colors.teal.shade200),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.merge_type_rounded, size: 11, color: Colors.teal.shade800),
                                const SizedBox(width: 3),
                                Text(
                                  "FitLoop + ${s.sourceName ?? 'Health Connect'}",
                                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.teal.shade800),
                                ),
                              ],
                            ),
                          ),
                        ] else if (s.isExternal) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: Colors.blue.shade200),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.watch_rounded, size: 11, color: Colors.blue.shade800),
                                const SizedBox(width: 3),
                                Text(
                                  s.sourceName ?? 'Health Connect',
                                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.blue.shade800),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),

                    const SizedBox(height: 8),

                    // Stats row (Volume + Total Sets + Calories / Distance) — Wrap prevents overflow
                    Wrap(
                      spacing: 10,
                      runSpacing: 4,
                      children: [
                        if (s.isExternal && !s.isMerged) ...[
                          if (s.distanceKm != null)
                            Text(
                              "Distance: ${s.distanceKm!.toStringAsFixed(2)} km",
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade700, fontWeight: FontWeight.w500),
                            ),
                          if (s.hasCalories)
                            Text(
                              "${s.distanceKm != null ? '•  ' : ''}${s.caloriesBurned} kcal",
                              style: TextStyle(fontSize: 12, color: Colors.orange.shade800, fontWeight: FontWeight.w600),
                            )
                          else
                            Text(
                              "${s.distanceKm != null ? '•  ' : ''}No calorie data",
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontStyle: FontStyle.italic),
                            ),
                        ] else ...[
                          Text(
                            "Volume: ${s.totalVolumeKg.toInt()} kg",
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade700, fontWeight: FontWeight.w500),
                          ),
                          Text(
                            "•  ${s.totalSets} sets",
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade700, fontWeight: FontWeight.w500),
                          ),
                          Text(
                            "•  ${s.caloriesBurned} kcal",
                            style: TextStyle(fontSize: 12, color: Colors.orange.shade800, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ],
                    ),

                    // PR Badges Strip
                    if (s.prBadges.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: s.prBadges.map((badge) {
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [Colors.amber.shade100, Colors.orange.shade100],
                              ),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: Colors.orange.shade300),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.emoji_events, color: Colors.orange, size: 13),
                                const SizedBox(width: 4),
                                Text(
                                  badge,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.orange.shade900,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // Expandable Breakdown of Exercises & Sets
            if (_isExpanded) ...[
              const Divider(height: 1),
              Container(
                color: Colors.grey.shade50,
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s.isExternal && !s.isMerged ? "EXTERNAL WORKOUT DETAILS" : "EXERCISE LOG DETAILS",
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.0,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (s.isExternal && !s.isMerged && s.exercises.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.info_outline, size: 14, color: Colors.blue),
                                const SizedBox(width: 6),
                                Text(
                                  "Imported via ${s.sourceName ?? 'Android Health Connect'}",
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black87),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              "Session duration: ${s.durationMinutes} minutes${s.distanceKm != null ? ' • Distance: ${s.distanceKm!.toStringAsFixed(2)} km' : ''}${s.hasCalories ? ' • Calories: ${s.caloriesBurned} kcal' : ''}",
                              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                      )
                    else
                      ...s.exercises.map((ex) => _buildExerciseDetailRow(ex)),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildExerciseDetailRow(CompletedExerciseLog ex) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  ex.exerciseName,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (ex.hasPersonalRecord) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade100,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    "PR SET",
                    style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.orange),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            children: ex.sets.map((set) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: set.isPersonalRecord ? Colors.amber.shade50 : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(4),
                  border: set.isPersonalRecord ? Border.all(color: Colors.amber) : null,
                ),
                child: Text(
                  "${set.weightKg.toInt()}kg × ${set.reps}",
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: set.isPersonalRecord ? FontWeight.bold : FontWeight.normal,
                    color: set.isPersonalRecord ? Colors.orange.shade900 : Colors.black87,
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

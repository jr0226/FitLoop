import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/workout_models.dart';
import '../../services/favorite_exercises_service.dart';
import 'add_to_routine_sheet.dart';

class ExerciseDetailModal extends StatelessWidget {
  final ExerciseModel exercise;
  final List<ExerciseModel> allLibraryExercises;
  final ValueChanged<ExerciseModel>? onSelectAlternative;
  final VoidCallback? onAddToWorkout;
  final bool? isFavorite;
  final VoidCallback? onToggleFavorite;

  const ExerciseDetailModal({
    super.key,
    required this.exercise,
    required this.allLibraryExercises,
    this.onSelectAlternative,
    this.onAddToWorkout,
    this.isFavorite,
    this.onToggleFavorite,
  });

  static Future<void> show(
    BuildContext context, {
    required ExerciseModel exercise,
    required List<ExerciseModel> allLibraryExercises,
    ValueChanged<ExerciseModel>? onSelectAlternative,
    VoidCallback? onAddToWorkout,
    bool? isFavorite,
    VoidCallback? onToggleFavorite,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ExerciseDetailModal(
        exercise: exercise,
        allLibraryExercises: allLibraryExercises,
        onSelectAlternative: onSelectAlternative,
        onAddToWorkout: onAddToWorkout,
        isFavorite: isFavorite,
        onToggleFavorite: onToggleFavorite,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final alternatives = allLibraryExercises
        .where((e) => exercise.alternativeIds.contains(e.id))
        .toList();

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: DraggableScrollableSheet(
        initialChildSize: 0.88,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        expand: false,
        builder: (context, scrollController) => Column(
          children: [
            // Drag Handle
            Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Modal Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      exercise.name,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                  StreamBuilder<Set<String>>(
                    stream: FavoriteExercisesService.getFavoriteExerciseIdsStream(),
                    builder: (context, snapshot) {
                      final effectiveId = FavoriteExercisesService.getEffectiveExerciseId(exercise);
                      final isFav = snapshot.data?.contains(effectiveId) ?? (isFavorite ?? false);
                      return IconButton(
                        icon: Icon(
                          isFav ? Icons.favorite : Icons.favorite_border,
                          color: isFav ? Colors.redAccent : Colors.grey.shade600,
                        ),
                        tooltip: isFav ? 'Remove from favorites' : 'Add to favorites',
                        onPressed: () async {
                          if (onToggleFavorite != null) {
                            onToggleFavorite!();
                          } else {
                            try {
                              await FavoriteExercisesService.toggleFavorite(exercise);
                            } catch (e) {
                              if (context.mounted) {
                                final isPermissionDenied = e is FirebaseException && e.code == 'permission-denied';
                                ScaffoldMessenger.of(context).hideCurrentSnackBar();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      isPermissionDenied
                                          ? "Unable to save favorite (Firestore permission denied - security rules update required)."
                                          : "Unable to save favorite. Please try again.",
                                    ),
                                    backgroundColor: Colors.red.shade700,
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              }
                            }
                          }
                        },
                      );
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            // Scrollable Content Body
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.all(20),
                children: [
                  // Tracking Mode Indicator
                  Container(
                    margin: const EdgeInsets.only(bottom: 14),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: exercise.trackingType.color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: exercise.trackingType.color.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(exercise.trackingType.icon, size: 16, color: exercise.trackingType.color),
                        const SizedBox(width: 8),
                        Text(
                          "Tracking Type: ${exercise.trackingType.displayName}",
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: exercise.trackingType.color,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // 1. Media Visualizer Container (Live GIF or Gradient Motion Guide)
                  Container(
                    height: 200,
                    width: double.infinity,
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.15),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (exercise.gifUrl != null && exercise.gifUrl!.isNotEmpty)
                          Image.network(
                            exercise.gifUrl!,
                            fit: BoxFit.contain,
                            loadingBuilder: (context, child, progress) {
                              if (progress == null) return child;
                              return Center(
                                child: CircularProgressIndicator(
                                  value: progress.expectedTotalBytes != null
                                      ? progress.cumulativeBytesLoaded / (progress.expectedTotalBytes ?? 1)
                                      : null,
                                  color: Colors.tealAccent,
                                ),
                              );
                            },
                            errorBuilder: (context, error, stackTrace) => Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.fitness_center_rounded, color: Colors.teal.shade300, size: 40),
                                  const SizedBox(height: 8),
                                  Text(
                                    exercise.name,
                                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                                  ),
                                ],
                              ),
                            ),
                          )
                        else
                          Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.teal.withValues(alpha: 0.2),
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.tealAccent, width: 1.5),
                                  ),
                                  child: const Icon(
                                    Icons.fitness_center_rounded,
                                    color: Colors.tealAccent,
                                    size: 40,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  "Exercise Guide: ${exercise.name}",
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        // Difficulty chip overlay
                        Positioned(
                          top: 12,
                          left: 12,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: exercise.difficulty.badgeColor.withValues(alpha: 0.85),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              exercise.difficulty.displayName.toUpperCase(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 10,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // 2. Metrics & Target Specifications
                  Row(
                    children: [
                      _buildDetailBadge(
                        Icons.track_changes,
                        "Target",
                        exercise.targetMuscle,
                        Colors.teal,
                      ),
                      const SizedBox(width: 10),
                      _buildDetailBadge(
                        Icons.handyman_outlined,
                        "Equipment",
                        exercise.equipment,
                        Colors.blue,
                      ),
                      const SizedBox(width: 10),
                      _buildDetailBadge(
                        Icons.timer_outlined,
                        "Rest",
                        "${exercise.restSeconds}s",
                        Colors.orange,
                      ),
                    ],
                  ),

                  if (exercise.secondaryMuscles.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text(
                      "Secondary Muscles Engaged:",
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      children: exercise.secondaryMuscles
                          .map((m) => Chip(
                                label: Text(m, style: const TextStyle(fontSize: 11)),
                                visualDensity: VisualDensity.compact,
                                backgroundColor: Colors.grey.shade100,
                              ))
                          .toList(),
                    ),
                  ],

                  const SizedBox(height: 24),

                  // 3. Step-by-Step Instructions
                  const Text(
                    "Execution Instructions",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),

                  if (exercise.instructions.isEmpty)
                    const Text(
                      "Maintain tight core bracing throughout all repetitions and focus on controlled eccentric tempo.",
                      style: TextStyle(color: Colors.black87, fontSize: 13, height: 1.4),
                    )
                  else
                    ...List.generate(exercise.instructions.length, (index) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                color: Colors.teal.shade50,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.teal),
                              ),
                              child: Center(
                                child: Text(
                                  "${index + 1}",
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.teal.shade900,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                exercise.instructions[index],
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Colors.black87,
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),

                  const SizedBox(height: 24),

                  // 4. Alternative Exercises Carousel
                  if (alternatives.isNotEmpty) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              const Icon(Icons.swap_calls_rounded, color: Colors.teal, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  "No ${exercise.equipment}? Alternatives",
                                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.teal.shade50,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            "${alternatives.length} options",
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.teal.shade800,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 124,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: alternatives.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 12),
                        itemBuilder: (context, index) {
                          final alt = alternatives[index];
                          return InkWell(
                            onTap: () {
                              Navigator.pop(context);
                              if (onSelectAlternative != null) {
                                onSelectAlternative!(alt);
                              } else {
                                ExerciseDetailModal.show(
                                  context,
                                  exercise: alt,
                                  allLibraryExercises: allLibraryExercises,
                                  onSelectAlternative: onSelectAlternative,
                                  onAddToWorkout: onAddToWorkout,
                                );
                              }
                            },
                            borderRadius: BorderRadius.circular(16),
                            child: Container(
                              width: 220,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: Colors.grey.shade300),
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
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(6),
                                        decoration: BoxDecoration(
                                          color: Colors.teal.shade50,
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: const Icon(Icons.sync_alt, color: Colors.teal, size: 16),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          alt.name,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                            color: Colors.black87,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Text(
                                    "Try with ${alt.equipment}",
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.teal.shade700,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: alt.difficulty.badgeColor.withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          alt.difficulty.displayName,
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: alt.difficulty.badgeColor,
                                          ),
                                        ),
                                      ),
                                      const Row(
                                        children: [
                                          Text(
                                            "View Form",
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.black54,
                                            ),
                                          ),
                                          Icon(Icons.chevron_right, size: 16, color: Colors.black54),
                                        ],
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],

                  const SizedBox(height: 30),

                  // Add To Active Workout or Save to Routine CTA
                  if (onAddToWorkout != null)
                    SizedBox(
                      height: 50,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          onAddToWorkout!();
                        },
                        icon: const Icon(Icons.add_rounded),
                        label: const Text(
                          "Add To Workout Routine",
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.teal,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    )
                  else
                    SizedBox(
                      height: 50,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          AddToRoutineSheet.show(context, exercise);
                        },
                        icon: const Icon(Icons.playlist_add_rounded),
                        label: const Text(
                          "Add To Routine",
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.teal,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailBadge(IconData icon, String title, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: color,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

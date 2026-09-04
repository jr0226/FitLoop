import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/workout_models.dart';

class FavoriteExercisesService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Generates a deterministic fallback exercise ID if stable ID is missing
  static String generateFallbackId(String name, String equipment) {
    final cleanName = name.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_');
    final cleanEquip = equipment.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_');
    return '${cleanName}_$cleanEquip';
  }

  /// Resolves the canonical ID for an exercise
  static String getEffectiveExerciseId(ExerciseModel exercise) {
    final id = exercise.id.trim();
    if (id.isNotEmpty && id != '0' && id.toLowerCase() != 'null') {
      return id;
    }
    return generateFallbackId(exercise.name, exercise.equipment);
  }

  /// Real-time stream of favorited exercise IDs for the current logged in user
  static Stream<Set<String>> getFavoriteExerciseIdsStream() {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        return Stream.value(<String>{});
      }

      return _firestore
          .collection('users')
          .doc(user.uid)
          .collection('favorite_exercises')
          .snapshots()
          .map((snap) => snap.docs.map((doc) => doc.id).toSet());
    } catch (e) {
      // In test/mock environments where Firebase is not initialized, return an empty stream
      return Stream.value(<String>{});
    }
  }

  /// Fetches all user favorite exercises as ExerciseModel list
  static Future<List<ExerciseModel>> getFavoriteExercises() async {
    final user = _auth.currentUser;
    if (user == null) return [];

    try {
      final snap = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('favorite_exercises')
          .orderBy('updatedAt', descending: true)
          .get();

      return snap.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return ExerciseModel.fromJson(data);
      }).toList();
    } catch (e) {
      debugPrint("[FavoriteExercisesService] Error loading favorite exercises: $e");
      return [];
    }
  }

  /// Toggles favorite status for an exercise. Returns true if added, false if removed.
  static Future<bool> toggleFavorite(ExerciseModel exercise) async {
    final user = _auth.currentUser;
    if (user == null) {
      debugPrint("[FavoriteExercisesService] toggleFavorite rejected: No authenticated user");
      throw Exception("User not authenticated");
    }

    final exerciseId = getEffectiveExerciseId(exercise);
    final docPath = 'users/${user.uid}/favorite_exercises/$exerciseId';
    final sanitizedPath = 'users/[UID]/favorite_exercises/$exerciseId';

    debugPrint("[FavoriteExercisesService] Initiating write: exerciseId='$exerciseId', path='$sanitizedPath'");

    final docRef = _firestore.doc(docPath);

    try {
      final doc = await docRef.get();
      if (doc.exists) {
        // Unfavorite -> remove
        await docRef.delete();
        debugPrint("[FavoriteExercisesService] Write SUCCESS: Removed favorite (exerciseId='$exerciseId', path='$sanitizedPath')");
        return false;
      } else {
        // Favorite -> save lightweight snapshot
        await docRef.set({
          'exerciseId': exerciseId,
          'name': exercise.name,
          'bodyPart': exercise.targetMuscle,
          'target': exercise.targetMuscle,
          'targetMuscle': exercise.targetMuscle,
          'secondaryMuscles': exercise.secondaryMuscles,
          'equipment': exercise.equipment,
          'gifUrl': exercise.gifUrl,
          'trackingType': exercise.trackingType.name,
          'difficulty': exercise.difficulty.displayName,
          'defaultSets': exercise.defaultSets,
          'defaultReps': exercise.defaultReps,
          'durationSeconds': exercise.durationSeconds,
          'instructions': exercise.instructions,
          'source': 'user_favorite',
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        debugPrint("[FavoriteExercisesService] Write SUCCESS: Saved favorite (exerciseId='$exerciseId', path='$sanitizedPath')");
        return true;
      }
    } on FirebaseException catch (fe) {
      debugPrint("[FavoriteExercisesService] Write FAILURE: Firestore exception code='${fe.code}', message='${fe.message}', exerciseId='$exerciseId', path='$sanitizedPath'");
      rethrow;
    } catch (e) {
      debugPrint("[FavoriteExercisesService] Write FAILURE: Unexpected exception: $e, exerciseId='$exerciseId', path='$sanitizedPath'");
      rethrow;
    }
  }

  /// Checks if a specific exercise ID is favorited
  static Future<bool> isFavorite(String exerciseId) async {
    final user = _auth.currentUser;
    if (user == null) return false;

    try {
      final doc = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('favorite_exercises')
          .doc(exerciseId)
          .get();
      return doc.exists;
    } catch (e) {
      return false;
    }
  }
}

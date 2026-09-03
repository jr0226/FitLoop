import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/achievement_model.dart';

/// Lightweight service to manage persistent user achievements in `users/{uid}/achievements/{achievementId}`.
class AchievementService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Subcollection reference helper for `users/{uid}/achievements`.
  static CollectionReference<Map<String, dynamic>> _achievementsRef(String uid) {
    return _firestore.collection('users').doc(uid).collection('achievements');
  }

  /// Synchronizes calculated user progress to persistent achievement documents in Firestore.
  /// Fully idempotent: preserves existing `unlockedAt` timestamps and prevents duplicate records.
  static Future<void> syncAchievementsFromStats({
    required String uid,
    required int totalWorkouts,
    required int currentStreak,
    required double totalWeightLifted,
    required int maxCaloriesOneSession,
    required int longestWorkoutSecs,
  }) async {
    final achievementsCollection = _achievementsRef(uid);
    final existingSnapshot = await achievementsCollection.get();
    final Map<String, DocumentSnapshot<Map<String, dynamic>>> existingDocs = {
      for (var doc in existingSnapshot.docs) doc.id: doc,
    };

    final batch = _firestore.batch();

    final List<Map<String, dynamic>> catalog = [
      {
        'id': 'first_workout',
        'type': 'workout_count',
        'title': 'First Steps',
        'description': 'Complete your first workout.',
        'category': 'workout',
        'progress': totalWorkouts.toDouble(),
        'target': 1.0,
      },
      {
        'id': 'streak_7',
        'type': 'streak',
        'title': 'Dedicated',
        'description': 'Reach a 7-Day Workout Streak.',
        'category': 'streak',
        'progress': currentStreak.toDouble(),
        'target': 7.0,
      },
      {
        'id': 'volume_1000',
        'type': 'volume',
        'title': 'Iron Club',
        'description': 'Lift over 1,000 kg total volume.',
        'category': 'strength',
        'progress': totalWeightLifted,
        'target': 1000.0,
      },
      {
        'id': 'session_cals_500',
        'type': 'session_calories',
        'title': 'Calorie Crusher',
        'description': 'Burn 500+ kcal in one session.',
        'category': 'workout',
        'progress': maxCaloriesOneSession.toDouble(),
        'target': 500.0,
      },
      {
        'id': 'workout_100',
        'type': 'workout_count',
        'title': 'Century Mark',
        'description': 'Complete 100 workouts.',
        'category': 'workout',
        'progress': totalWorkouts.toDouble(),
        'target': 100.0,
      },
      {
        'id': 'duration_60m',
        'type': 'duration',
        'title': 'Endurance Master',
        'description': 'Workout for over 60 minutes in a single session.',
        'category': 'workout',
        'progress': longestWorkoutSecs.toDouble(),
        'target': 3600.0,
      },
    ];

    for (var item in catalog) {
      final String id = item['id'];
      final docRef = achievementsCollection.doc(id);
      final existingDoc = existingDocs[id];
      final double progress = item['progress'];
      final double target = item['target'];
      final bool qualifiesForUnlock = progress >= target;

      final bool alreadyUnlocked = existingDoc?.data()?['isUnlocked'] == true;
      final isUnlocked = alreadyUnlocked || qualifiesForUnlock;

      final Map<String, dynamic> payload = {
        'type': item['type'],
        'title': item['title'],
        'description': item['description'],
        'category': item['category'],
        'progress': progress,
        'target': target,
        'isUnlocked': isUnlocked,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (existingDoc == null || !existingDoc.exists) {
        payload['createdAt'] = FieldValue.serverTimestamp();
      }

      // Preserve existing unlockedAt if already unlocked, or stamp it if newly unlocking
      if (alreadyUnlocked) {
        // Keep existing unlockedAt without overwriting
      } else if (qualifiesForUnlock) {
        payload['unlockedAt'] = FieldValue.serverTimestamp();
      }

      batch.set(docRef, payload, SetOptions(merge: true));
    }

    await batch.commit();
  }

  /// Streams user achievements ordered by title.
  static Stream<List<UserAchievement>> streamAchievements(String uid) {
    return _achievementsRef(uid)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => UserAchievement.fromFirestore(doc))
            .toList());
  }

  /// Fetches persistent user achievements from Firestore.
  static Future<List<UserAchievement>> getAchievements(String uid) async {
    final snapshot = await _achievementsRef(uid).get();
    return snapshot.docs
        .map((doc) => UserAchievement.fromFirestore(doc))
        .toList();
  }
}

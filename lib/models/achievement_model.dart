import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a persistent user achievement stored in `users/{uid}/achievements/{achievementId}`.
class UserAchievement {
  final String id;
  final String type;
  final String title;
  final String description;
  final String category; // e.g. "workout", "streak", "strength", "nutrition"
  final double progress;
  final double target;
  final bool isUnlocked;
  final DateTime? unlockedAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final Map<String, dynamic>? metadata;

  const UserAchievement({
    required this.id,
    required this.type,
    required this.title,
    required this.description,
    required this.category,
    required this.progress,
    required this.target,
    required this.isUnlocked,
    this.unlockedAt,
    this.createdAt,
    this.updatedAt,
    this.metadata,
  });

  factory UserAchievement.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    final dynamic rawUnlockedAt = data['unlockedAt'];
    final DateTime? unlockedAt = rawUnlockedAt is Timestamp
        ? rawUnlockedAt.toDate()
        : (rawUnlockedAt is DateTime ? rawUnlockedAt : null);

    final dynamic rawCreatedAt = data['createdAt'];
    final DateTime? createdAt = rawCreatedAt is Timestamp
        ? rawCreatedAt.toDate()
        : (rawCreatedAt is DateTime ? rawCreatedAt : null);

    final dynamic rawUpdatedAt = data['updatedAt'];
    final DateTime? updatedAt = rawUpdatedAt is Timestamp
        ? rawUpdatedAt.toDate()
        : (rawUpdatedAt is DateTime ? rawUpdatedAt : null);

    return UserAchievement(
      id: doc.id,
      type: data['type']?.toString() ?? '',
      title: data['title']?.toString() ?? '',
      description: data['description']?.toString() ?? '',
      category: data['category']?.toString() ?? 'workout',
      progress: (data['progress'] as num?)?.toDouble() ?? 0.0,
      target: (data['target'] as num?)?.toDouble() ?? 1.0,
      isUnlocked: data['isUnlocked'] == true,
      unlockedAt: unlockedAt,
      createdAt: createdAt,
      updatedAt: updatedAt,
      metadata: data['metadata'] is Map ? Map<String, dynamic>.from(data['metadata']) : null,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'type': type,
      'title': title,
      'description': description,
      'category': category,
      'progress': progress,
      'target': target,
      'isUnlocked': isUnlocked,
      if (unlockedAt != null) 'unlockedAt': Timestamp.fromDate(unlockedAt!),
      'updatedAt': FieldValue.serverTimestamp(),
      if (metadata != null) 'metadata': metadata,
    };
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a single body measurement / progress record stored in `users/{uid}/measurements/{measurementId}`.
class BodyMeasurement {
  final String id;
  final double? weight; // canonical unit: kg
  final double? bodyFatPercentage; // percentage (e.g. 15.5)
  final double? waist; // canonical unit: cm
  final double? chest; // canonical unit: cm
  final double? arms; // canonical unit: cm
  final double? hips; // canonical unit: cm
  final DateTime date;
  final DateTime? createdAt;
  final String source;

  const BodyMeasurement({
    required this.id,
    this.weight,
    this.bodyFatPercentage,
    this.waist,
    this.chest,
    this.arms,
    this.hips,
    required this.date,
    this.createdAt,
    this.source = 'manual',
  });

  factory BodyMeasurement.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    final dynamic rawDate = data['date'] ?? data['timestamp'];
    final DateTime parsedDate = rawDate is Timestamp
        ? rawDate.toDate()
        : (rawDate is DateTime ? rawDate : DateTime.now());

    final dynamic rawCreatedAt = data['createdAt'];
    final DateTime? parsedCreatedAt = rawCreatedAt is Timestamp
        ? rawCreatedAt.toDate()
        : (rawCreatedAt is DateTime ? rawCreatedAt : null);

    return BodyMeasurement(
      id: doc.id,
      weight: (data['weight'] as num?)?.toDouble(),
      bodyFatPercentage: (data['bodyFatPercentage'] as num?)?.toDouble(),
      waist: (data['waist'] as num?)?.toDouble(),
      chest: (data['chest'] as num?)?.toDouble(),
      arms: (data['arms'] as num?)?.toDouble(),
      hips: (data['hips'] as num?)?.toDouble(),
      date: parsedDate,
      createdAt: parsedCreatedAt,
      source: data['source']?.toString() ?? 'manual',
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      if (weight != null) 'weight': weight,
      if (bodyFatPercentage != null) 'bodyFatPercentage': bodyFatPercentage,
      if (waist != null) 'waist': waist,
      if (chest != null) 'chest': chest,
      if (arms != null) 'arms': arms,
      if (hips != null) 'hips': hips,
      'date': Timestamp.fromDate(date),
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
      'source': source,
    };
  }
}

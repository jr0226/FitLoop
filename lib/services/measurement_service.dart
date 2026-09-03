import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/measurement_model.dart';

/// Lightweight service for managing body measurement history in `users/{uid}/measurements/{measurementId}`.
class MeasurementService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Helper to get the `users/{uid}/measurements` subcollection reference.
  static CollectionReference<Map<String, dynamic>> _measurementsRef(String uid) {
    return _firestore.collection('users').doc(uid).collection('measurements');
  }

  /// Adds a new measurement entry into Firestore.
  static Future<DocumentReference<Map<String, dynamic>>> addMeasurement({
    required String uid,
    double? weight,
    double? bodyFatPercentage,
    double? waist,
    double? chest,
    double? arms,
    double? hips,
    DateTime? date,
    String source = 'manual',
  }) async {
    final measurement = BodyMeasurement(
      id: '',
      weight: weight,
      bodyFatPercentage: bodyFatPercentage,
      waist: waist,
      chest: chest,
      arms: arms,
      hips: hips,
      date: date ?? DateTime.now(),
      source: source,
    );

    return await _measurementsRef(uid).add(measurement.toFirestore());
  }

  /// Records a historical weight entry ONLY if the weight has actually changed.
  /// Prevents spamming duplicate measurement history on repeated profile saves.
  static Future<void> recordWeightIfChanged({
    required String uid,
    required double newWeight,
    double? previousWeight,
    String source = 'profile_update',
  }) async {
    if (previousWeight != null && (previousWeight - newWeight).abs() < 0.001) {
      return; // Unchanged weight, skip duplicate entry
    }

    await addMeasurement(
      uid: uid,
      weight: newWeight,
      date: DateTime.now(),
      source: source,
    );
  }

  /// Streams user measurements ordered chronologically (most recent first).
  static Stream<List<BodyMeasurement>> streamMeasurements(String uid) {
    return _measurementsRef(uid)
        .orderBy('date', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => BodyMeasurement.fromFirestore(doc))
            .toList());
  }

  /// Fetches historical measurements.
  static Future<List<BodyMeasurement>> getMeasurements(String uid, {int limit = 50}) async {
    final query = await _measurementsRef(uid)
        .orderBy('date', descending: true)
        .limit(limit)
        .get();

    return query.docs
        .map((doc) => BodyMeasurement.fromFirestore(doc))
        .toList();
  }

  /// Deletes a measurement record.
  static Future<void> deleteMeasurement({
    required String uid,
    required String measurementId,
  }) async {
    await _measurementsRef(uid).doc(measurementId).delete();
  }
}

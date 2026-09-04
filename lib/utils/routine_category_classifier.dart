import '../models/workout_models.dart';

/// Centralized categorization and classification utility for workout routines.
/// Eliminates naive exact-match string comparisons and handles multi-tier fallback evidence:
/// 1. Explicit Category
/// 2. WorkoutType / Subtitle
/// 3. Routine Name
/// 4. Exercise Composition (majority vote)
class RoutineCategoryClassifier {
  /// Upper Body movement groups and subcategories
  static const Set<String> _upperBodyCategories = {
    'upper body',
    'chest',
    'back',
    'arms',
    'shoulders',
    'biceps',
    'triceps',
    'push',
    'pull',
    'pecs',
    'lats',
    'deltoids',
    'traps',
  };

  /// Lower Body movement groups and subcategories
  static const Set<String> _lowerBodyCategories = {
    'lower body',
    'legs',
    'glutes',
    'quads',
    'hamstrings',
    'calves',
    'leg day',
    'calisthenics legs',
  };

  /// Core / Abdominal groups and aliases
  static const Set<String> _coreCategories = {
    'core',
    'waist',
    'abs',
    'abdominals',
    'midsection',
    'obliques',
  };

  /// Cardio & Conditioning groups and aliases
  static const Set<String> _cardioCategories = {
    'cardio',
    'conditioning',
    'running',
    'cycling',
    'hiit',
    'aerobic',
    'endurance',
    'stamina',
  };

  /// Determines whether a routine matches the user-selected tab category using a 4-tier fallback:
  /// 1. Explicit category
  /// 2. Routine workoutType / subtitle
  /// 3. Routine name keywords
  /// 4. Exercise composition majority
  static bool matchesRoutine(WorkoutRoutine routine, String targetTabCategory) {
    final cleanTab = targetTabCategory.trim().toLowerCase();
    if (cleanTab == 'all' || cleanTab.isEmpty) {
      return true;
    }

    // 1. Tier 1: Check routine explicit category
    if (matchesCategory(routine.category, cleanTab)) {
      return true;
    }

    // 2. Tier 2: Check subtitle / workoutType hints if present
    if (routine.subtitle.isNotEmpty && matchesCategory(routine.subtitle, cleanTab)) {
      return true;
    }

    // 3. Tier 3: Check routine name keywords
    final cleanName = routine.title.trim().toLowerCase();
    if (_matchesCategoryKeywords(cleanName, cleanTab)) {
      return true;
    }

    // 4. Tier 4: Exercise composition fallback (majority targeting)
    if (routine.exercises.isNotEmpty) {
      final inferredCategory = inferCategoryFromExercises(routine.exercises);
      if (inferredCategory != null && matchesCategory(inferredCategory, cleanTab)) {
        return true;
      }
    }

    return false;
  }

  /// Internal helper to check keywords in a string against category definitions
  static bool _matchesCategoryKeywords(String text, String cleanTab) {
    if (cleanTab == 'lower body') {
      return _lowerBodyCategories.any((c) => text.contains(c));
    }
    if (cleanTab == 'upper body') {
      return _upperBodyCategories.any((c) => text.contains(c));
    }
    if (cleanTab == 'core') {
      return _coreCategories.any((c) => text.contains(c));
    }
    if (cleanTab == 'cardio') {
      return _cardioCategories.any((c) => text.contains(c));
    }
    if (cleanTab == 'full body') {
      return text.contains('full body');
    }
    return text.contains(cleanTab);
  }

  /// Infers broad category from exercise list composition.
  /// Counts exercises targeting Upper Body, Lower Body, Core, Cardio.
  /// If a single group represents >= 50% of the exercises (or the majority), classifies accordingly.
  /// If both upper and lower exercises are substantially present, classifies as 'Full Body'.
  static String? inferCategoryFromExercises(List<ExerciseModel> exercises) {
    if (exercises.isEmpty) return null;

    int upperCount = 0;
    int lowerCount = 0;
    int coreCount = 0;
    int cardioCount = 0;

    for (final ex in exercises) {
      final target = ex.targetMuscle.trim().toLowerCase();
      final name = ex.name.trim().toLowerCase();

      // Lower body exercise indicator
      if (_lowerBodyCategories.any((c) => target.contains(c)) ||
          name.contains('squat') ||
          name.contains('lunge') ||
          name.contains('deadlift') ||
          name.contains('leg press') ||
          name.contains('leg curl') ||
          name.contains('leg extension') ||
          name.contains('calf raise') ||
          name.contains('hip thrust') ||
          name.contains('glute bridge') ||
          name.contains('romanian deadlift') ||
          name.contains('rdl')) {
        lowerCount++;
      }
      // Upper body exercise indicator
      else if (_upperBodyCategories.any((c) => target.contains(c)) ||
          name.contains('bench press') ||
          name.contains('push-up') ||
          name.contains('push up') ||
          name.contains('pull-up') ||
          name.contains('pull up') ||
          name.contains('chin-up') ||
          name.contains('chin up') ||
          name.contains('dip') ||
          name.contains('shoulder press') ||
          name.contains('overhead press') ||
          name.contains('lat pulldown') ||
          name.contains('row') ||
          name.contains('bicep curl') ||
          name.contains('tricep extension') ||
          name.contains('lateral raise') ||
          name.contains('arnold press')) {
        upperCount++;
      }
      // Core exercise indicator
      else if (_coreCategories.any((c) => target.contains(c)) ||
          name.contains('plank') ||
          name.contains('crunch') ||
          name.contains('sit-up') ||
          name.contains('sit up') ||
          name.contains('leg raise') ||
          name.contains('russian twist') ||
          name.contains('dead bug') ||
          name.contains('bird dog') ||
          name.contains('hollow body')) {
        coreCount++;
      }
      // Cardio exercise indicator
      else if (_cardioCategories.any((c) => target.contains(c)) ||
          ex.trackingType == ExerciseTrackingType.cardio ||
          name.contains('bike') ||
          name.contains('running') ||
          name.contains('jogging') ||
          name.contains('treadmill') ||
          name.contains('jump rope') ||
          name.contains('burpee') ||
          name.contains('mountain climber')) {
        cardioCount++;
      }
    }

    final total = exercises.length;

    // Strict mixed Upper + Lower composition -> Full Body
    if (upperCount >= 2 && lowerCount >= 2) {
      return 'Full Body';
    }

    // Majority checks (>= 50% or highest count if clear winner)
    if (lowerCount >= (total / 2).ceil() || (lowerCount > upperCount && lowerCount > coreCount && lowerCount > cardioCount && lowerCount >= 2)) {
      return 'Lower Body';
    }
    if (upperCount >= (total / 2).ceil() || (upperCount > lowerCount && upperCount > coreCount && upperCount > cardioCount && upperCount >= 2)) {
      return 'Upper Body';
    }
    if (coreCount >= (total / 2).ceil()) {
      return 'Core';
    }
    if (cardioCount >= (total / 2).ceil()) {
      return 'Cardio';
    }

    return null;
  }

  /// Determines whether a routine's stored category matches the user-selected tab category.
  /// Supports raw category string matching with fallback support.
  static bool matchesCategory(String routineCategory, String targetTabCategory) {
    final cleanTab = targetTabCategory.trim().toLowerCase();
    final cleanRoutine = routineCategory.trim().toLowerCase();

    if (cleanTab == 'all' || cleanTab.isEmpty) {
      return true;
    }

    if (cleanTab == 'upper body') {
      return _upperBodyCategories.any((c) => cleanRoutine.contains(c));
    }

    if (cleanTab == 'lower body') {
      return _lowerBodyCategories.any((c) => cleanRoutine.contains(c));
    }

    if (cleanTab == 'core') {
      return _coreCategories.any((c) => cleanRoutine.contains(c));
    }

    if (cleanTab == 'cardio') {
      return _cardioCategories.any((c) => cleanRoutine.contains(c));
    }

    if (cleanTab == 'full body') {
      return cleanRoutine.contains('full body');
    }

    // Direct substring or equality check for explicit categories (e.g. Chest, Arms)
    return cleanRoutine.contains(cleanTab) || cleanTab.contains(cleanRoutine);
  }

  /// Returns canonical list of UI categories a routine belongs to.
  /// Evaluates explicit category, title keywords, and exercise composition.
  static List<String> getCanonicalCategories(String routineCategory, {String? routineTitle, List<ExerciseModel>? exercises}) {
    final clean = routineCategory.trim().toLowerCase();
    final title = (routineTitle ?? '').trim().toLowerCase();
    final List<String> memberships = ['All'];

    final isUpper = _upperBodyCategories.any((c) => clean.contains(c) || title.contains(c));
    final isLower = _lowerBodyCategories.any((c) => clean.contains(c) || title.contains(c));
    final isCore = _coreCategories.any((c) => clean.contains(c) || title.contains(c));
    final isCardio = _cardioCategories.any((c) => clean.contains(c) || title.contains(c));
    final isFull = clean.contains('full body') || title.contains('full body');

    if (isUpper) memberships.add('Upper Body');
    if (isLower) memberships.add('Lower Body');
    if (isCore) memberships.add('Core');
    if (isCardio) memberships.add('Cardio');
    if (isFull) memberships.add('Full Body');

    // Exercise composition fallback if no specific category was found
    if (memberships.length == 1 && exercises != null && exercises.isNotEmpty) {
      final inferred = inferCategoryFromExercises(exercises);
      if (inferred != null && !memberships.contains(inferred)) {
        memberships.add(inferred);
      }
    }

    return memberships;
  }

  /// Formats a concise metadata line for cards, e.g.:
  /// "Beginner • Upper Body • Dumbbells"
  static String formatRoutineMetadata(WorkoutRoutine routine) {
    final level = routine.level.displayName;
    final category = routine.category;
    final equipment = routine.primaryEquipment;
    return '$level • $category • $equipment';
  }
}

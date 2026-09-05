/// Canonical Workout Category Validator & Repair Engine for FitLoop.
///
/// Ensures deterministic post-generation validation and repair across all 13 categories:
/// - Cardio, HIIT, Core, Chest, Back, Arms, Shoulders, Legs,
/// - Upper Body, Lower Body, Full Body, Push, Pull.
///
/// Disallows resistance exercises in Cardio, ensures balanced coverage in Full Body,
/// enforces equipment and fitness level constraints, and eliminates duplicates/aliases.
class WorkoutCategoryValidator {
  // ─── CANONICAL TARGET & MOVEMENT CLASSIFICATION ─────────────────────────────

  static const Set<String> _cardioKeywords = {
    'running', 'jogging', 'sprint', 'treadmill', 'cycling', 'bike', 'air bike',
    'rowing machine', 'rower', 'elliptical', 'stair climber', 'stairmaster',
    'jump rope', 'skipping', 'high knees', 'butt kicks', 'jumping jacks',
    'mountain climbers', 'burpees', 'box jump', 'shadow boxing', 'lateral shuffles',
    'shuttle runs', 'skater jumps', 'step ups',
  };

  static const Set<String> _cardioForbiddenResistanceKeywords = {
    'push-up', 'push up', 'pushup', 'bench press', 'chest press', 'chest fly',
    'dumbbell row', 'barbell row', 'lat pulldown', 'pull-up', 'pull up', 'chin-up',
    'bicep curl', 'biceps curl', 'hammer curl', 'tricep extension', 'triceps extension',
    'skull crusher', 'overhead press', 'shoulder press', 'military press',
    'lateral raise', 'front raise', 'barbell squat', 'hack squat', 'leg press',
    'deadlift', 'leg curl', 'leg extension', 'calf raise',
  };

  static const Set<String> _chestKeywords = {
    'bench press', 'chest press', 'push-up', 'push up', 'pushup', 'chest fly',
    'pec fly', 'cable fly', 'incline press', 'decline press', 'dips', 'chest dip',
  };

  static const Set<String> _backKeywords = {
    'row', 'lat pulldown', 'pull-up', 'pull up', 'pullup', 'chin-up', 'chin up',
    'chinup', 'deadlift', 'superman', 'back extension', 'face pull', 'shrug',
    'inverted row', 't-bar row',
  };

  static const Set<String> _armsKeywords = {
    'curl', 'bicep', 'biceps', 'tricep', 'triceps', 'dip', 'dips', 'pushdown',
    'skull crusher', 'french press', 'kickback', 'preacher curl', 'hammer curl',
    'wrist curl', 'forearm',
  };

  static const Set<String> _shouldersKeywords = {
    'overhead press', 'shoulder press', 'military press', 'arnold press',
    'lateral raise', 'side lateral', 'front raise', 'rear delt', 'pike push-up',
    'pike push up', 'handstand push-up', 'upright row', 'face pull',
  };

  static const Set<String> _legsKeywords = {
    'squat', 'lunge', 'deadlift', 'leg press', 'hack squat', 'leg curl',
    'leg extension', 'calf raise', 'romanian deadlift', 'rdl', 'glute bridge',
    'hip thrust', 'step up', 'step-up', 'split squat', 'goblet squat',
  };

  static const Set<String> _coreKeywords = {
    'plank', 'crunch', 'sit-up', 'sit up', 'dead bug', 'bird dog', 'russian twist',
    'leg raise', 'hollow body', 'ab wheel', 'hanging leg raise', 'mountain climber',
    'bicycle crunch', 'flutter kicks', 'side plank', 'v-up', 'toe touches',
  };

  static const Set<String> _hiitKeywords = {
    'burpee', 'mountain climber', 'jump squat', 'jumping jack', 'high knees',
    'kettlebell swing', 'battle rope', 'box jump', 'skater jump', 'sprint',
    'push-up to tuck jump', 'plyo lunge',
  };

  // ─── GUARANTEED SAFE CANONICAL EXERCISE POOLS (BY CATEGORY & EQUIPMENT) ────

  static const Map<String, List<Map<String, dynamic>>> _fallbackLibrary = {
    'cardio': [
      {'name': 'Jumping Jacks', 'target': 'Cardio', 'equipment': 'Bodyweight', 'sets': '3 sets x 45s', 'durationSeconds': 45, 'desc': 'Light on toes, steady rhythmic jumping.'},
      {'name': 'High Knees', 'target': 'Cardio', 'equipment': 'Bodyweight', 'sets': '3 sets x 30s', 'durationSeconds': 30, 'desc': 'Drive knees up toward chest with active arm swing.'},
      {'name': 'Mountain Climbers', 'target': 'Cardio', 'equipment': 'Bodyweight', 'sets': '3 sets x 40s', 'durationSeconds': 40, 'desc': 'Plank position, alternate knees rapidly to chest.'},
      {'name': 'Jump Rope', 'target': 'Cardio', 'equipment': 'Jump Rope', 'sets': '3 sets x 60s', 'durationSeconds': 60, 'desc': 'Quick wrist rotations and light hops.'},
      {'name': 'Burpees', 'target': 'Cardio', 'equipment': 'Bodyweight', 'sets': '3 sets x 30s', 'durationSeconds': 30, 'desc': 'Full body conditioning drop-down and explosive hop.'},
      {'name': 'Running / Jogging in Place', 'target': 'Cardio', 'equipment': 'Bodyweight', 'sets': '3 sets x 60s', 'durationSeconds': 60, 'desc': 'Maintain steady cadence and deep breathing.'},
      {'name': 'Stationary Cycling', 'target': 'Cardio', 'equipment': 'Stationary Bike', 'sets': '1 set x 15 mins', 'durationSeconds': 900, 'desc': 'Moderate cadence steady cardiovascular effort.'},
    ],
    'hiit': [
      {'name': 'Burpees', 'target': 'Full Body', 'equipment': 'Bodyweight', 'sets': '4 sets x 30s', 'durationSeconds': 30, 'desc': 'High intensity conditioning cycle.'},
      {'name': 'Jump Squats', 'target': 'Legs', 'equipment': 'Bodyweight', 'sets': '4 sets x 30s', 'durationSeconds': 30, 'desc': 'Explosive jump from bottom of squat.'},
      {'name': 'Mountain Climbers', 'target': 'Cardio', 'equipment': 'Bodyweight', 'sets': '4 sets x 30s', 'durationSeconds': 30, 'desc': 'Paced sprint drive in plank.'},
      {'name': 'High Knees', 'target': 'Cardio', 'equipment': 'Bodyweight', 'sets': '4 sets x 30s', 'durationSeconds': 30, 'desc': 'Maximum effort knee drives.'},
      {'name': 'Kettlebell Swings', 'target': 'Full Body', 'equipment': 'Kettlebell', 'sets': '4 sets x 40s', 'durationSeconds': 40, 'desc': 'Hip hinge explosive drive.'},
    ],
    'chest': [
      {'name': 'Push-Ups', 'target': 'Chest', 'equipment': 'Bodyweight', 'sets': '3 sets x 12 reps', 'desc': 'Keep core braced and elbows at 45 degrees.'},
      {'name': 'Incline Push-Ups', 'target': 'Chest', 'equipment': 'Bodyweight', 'sets': '3 sets x 12 reps', 'desc': 'Hands elevated on bench or step for upper chest focus.'},
      {'name': 'Dumbbell Bench Press', 'target': 'Chest', 'equipment': 'Dumbbells', 'sets': '3 sets x 10 reps', 'desc': 'Press dumbbells smoothly overhead from bench.'},
      {'name': 'Dumbbell Chest Fly', 'target': 'Chest', 'equipment': 'Dumbbells', 'sets': '3 sets x 12 reps', 'desc': 'Arc weights outwards with slight elbow bend.'},
      {'name': 'Dips', 'target': 'Chest', 'equipment': 'Bodyweight', 'sets': '3 sets x 10 reps', 'desc': 'Lean forward slightly for lower pectoral engagement.'},
    ],
    'back': [
      {'name': 'Dumbbell Bent-Over Row', 'target': 'Back', 'equipment': 'Dumbbells', 'sets': '3 sets x 10 reps', 'desc': 'Hinge hips back and pull elbows towards waist.'},
      {'name': 'Prone Back Extensions (Superman)', 'target': 'Back', 'equipment': 'Bodyweight', 'sets': '3 sets x 12 reps', 'desc': 'Lift chest and legs simultaneously while squeezing back.'},
      {'name': 'Pull-Ups', 'target': 'Back', 'equipment': 'Pull-up Bar', 'sets': '3 sets x 8 reps', 'desc': 'Full grip pull until chin clears bar.'},
      {'name': 'Inverted Row', 'target': 'Back', 'equipment': 'Bodyweight', 'sets': '3 sets x 10 reps', 'desc': 'Bodyweight row under sturdy bar or table.'},
      {'name': 'Single-Arm Dumbbell Row', 'target': 'Back', 'equipment': 'Dumbbells', 'sets': '3 sets x 10 reps', 'desc': 'Support on bench and row weight smoothly to hip.'},
    ],
    'arms': [
      {'name': 'Dumbbell Bicep Curl', 'target': 'Arms', 'equipment': 'Dumbbells', 'sets': '3 sets x 12 reps', 'desc': 'Curl weights up with controlled supination.'},
      {'name': 'Chair / Bench Dips', 'target': 'Arms', 'equipment': 'Bodyweight', 'sets': '3 sets x 12 reps', 'desc': 'Lower body with elbows pointing straight back.'},
      {'name': 'Dumbbell Overhead Tricep Extension', 'target': 'Arms', 'equipment': 'Dumbbells', 'sets': '3 sets x 12 reps', 'desc': 'Lower dumbbell behind head and extend upward.'},
      {'name': 'Hammer Curls', 'target': 'Arms', 'equipment': 'Dumbbells', 'sets': '3 sets x 12 reps', 'desc': 'Neutral grip curling targeting brachialis.'},
      {'name': 'Diamond Push-Ups', 'target': 'Arms', 'equipment': 'Bodyweight', 'sets': '3 sets x 10 reps', 'desc': 'Hands close together under chest for triceps.'},
    ],
    'shoulders': [
      {'name': 'Dumbbell Shoulder Press', 'target': 'Shoulders', 'equipment': 'Dumbbells', 'sets': '3 sets x 10 reps', 'desc': 'Press dumbbells vertically overhead with neutral core.'},
      {'name': 'Dumbbell Lateral Raise', 'target': 'Shoulders', 'equipment': 'Dumbbells', 'sets': '3 sets x 12 reps', 'desc': 'Raise arms to sides until parallel to floor.'},
      {'name': 'Pike Push-Ups', 'target': 'Shoulders', 'equipment': 'Bodyweight', 'sets': '3 sets x 10 reps', 'desc': 'Hips high in inverted V, press crown of head downward.'},
      {'name': 'Dumbbell Front Raise', 'target': 'Shoulders', 'equipment': 'Dumbbells', 'sets': '3 sets x 12 reps', 'desc': 'Raise dumbbells directly forward to eye level.'},
    ],
    'legs': [
      {'name': 'Bodyweight Air Squats', 'target': 'Legs', 'equipment': 'Bodyweight', 'sets': '3 sets x 15 reps', 'desc': 'Hips back, chest tall, thighs parallel to ground.'},
      {'name': 'Walking Lunges', 'target': 'Legs', 'equipment': 'Bodyweight', 'sets': '3 sets x 12 reps', 'desc': 'Step forward into 90-degree knee bend.'},
      {'name': 'Dumbbell Goblet Squat', 'target': 'Legs', 'equipment': 'Dumbbells', 'sets': '3 sets x 10 reps', 'desc': 'Hold dumbbell close to chest and squat smoothly.'},
      {'name': 'Romanian Deadlift (RDL)', 'target': 'Legs', 'equipment': 'Dumbbells', 'sets': '3 sets x 10 reps', 'desc': 'Hinge at hips, keep back flat, stretch hamstrings.'},
      {'name': 'Glute Bridges', 'target': 'Legs', 'equipment': 'Bodyweight', 'sets': '3 sets x 15 reps', 'desc': 'Drive through heels to lift hips to full glute contraction.'},
      {'name': 'Standing Calf Raises', 'target': 'Legs', 'equipment': 'Bodyweight', 'sets': '3 sets x 20 reps', 'desc': 'Elevate heels high and pause at top.'},
    ],
    'core': [
      {'name': 'Forearm Plank', 'target': 'Core', 'equipment': 'Bodyweight', 'sets': '3 sets x 45s', 'durationSeconds': 45, 'desc': 'Hold straight line from shoulders to heels.'},
      {'name': 'Dead Bug', 'target': 'Core', 'equipment': 'Bodyweight', 'sets': '3 sets x 12 reps', 'desc': 'Lower opposite arm and leg while pressing lower back to floor.'},
      {'name': 'Bicycle Crunches', 'target': 'Core', 'equipment': 'Bodyweight', 'sets': '3 sets x 20 reps', 'desc': 'Rotate torso bringing opposite elbow to knee.'},
      {'name': 'Russian Twists', 'target': 'Core', 'equipment': 'Bodyweight', 'sets': '3 sets x 20 reps', 'desc': 'Rotate torso side to side with feet slightly raised.'},
      {'name': 'Hanging Leg Raises', 'target': 'Core', 'equipment': 'Pull-up Bar', 'sets': '3 sets x 10 reps', 'desc': 'Smoothly raise straight legs from pull-up bar.'},
    ],
  };

  // ─── NORMALIZATION HELPERS ──────────────────────────────────────────────────

  /// Normalizes exercise name to catch aliases (e.g. "Push-Up", "Push Up", "Standard Pushups" -> "pushup")
  static String normalizeExerciseName(String name) {
    var s = name.trim().toLowerCase();
    s = s.replaceAll(RegExp(r'[^a-z0-9]'), ''); // remove hyphens, spaces, punctuation
    // Remove redundant common prefixes
    for (var p in ['standard', 'bodyweight', 'dumbbell', 'barbell', 'cable', 'machine', 'exercise']) {
      if (s.startsWith(p)) {
        final rest = s.substring(p.length);
        if (rest.isNotEmpty) s = rest;
      }
    }
    // Plural to singular
    if (s.endsWith('s') && !s.endsWith('ss') && s.length > 3) {
      s = s.substring(0, s.length - 1);
    }
    return s;
  }

  /// Categorizes an exercise by its name, target muscle, or description
  static String inferExerciseCategory(String name, [String? target]) {
    final n = name.toLowerCase();
    final t = (target ?? '').toLowerCase();

    if (_cardioKeywords.any((k) => n.contains(k) || t.contains(k))) return 'Cardio';
    if (_hiitKeywords.any((k) => n.contains(k) || t.contains(k))) return 'HIIT';
    if (_chestKeywords.any((k) => n.contains(k) || t.contains(k))) return 'Chest';
    if (_backKeywords.any((k) => n.contains(k) || t.contains(k))) return 'Back';
    if (_shouldersKeywords.any((k) => n.contains(k) || t.contains(k))) return 'Shoulders';
    if (_armsKeywords.any((k) => n.contains(k) || t.contains(k))) return 'Arms';
    if (_legsKeywords.any((k) => n.contains(k) || t.contains(k))) return 'Legs';
    if (_coreKeywords.any((k) => n.contains(k) || t.contains(k))) return 'Core';

    if (t.contains('pectoral') || t.contains('chest')) return 'Chest';
    if (t.contains('lat') || t.contains('trap') || t.contains('back')) return 'Back';
    if (t.contains('delt') || t.contains('shoulder')) return 'Shoulders';
    if (t.contains('bicep') || t.contains('tricep') || t.contains('forearm')) return 'Arms';
    if (t.contains('quad') || t.contains('hamstring') || t.contains('glute') || t.contains('calf')) return 'Legs';
    if (t.contains('ab') || t.contains('waist') || t.contains('oblique') || t.contains('core')) return 'Core';

    return 'Full Body';
  }

  // ─── CATEGORY COMPATIBILITY CHECK ───────────────────────────────────────────

  /// Deterministically validates if an exercise is valid for the requested routine category.
  static bool isExerciseValidForCategory(Map<String, dynamic> exercise, String routineCategory) {
    final cat = routineCategory.trim().toLowerCase();
    final name = (exercise['name'] ?? exercise['exerciseName'] ?? '').toString().toLowerCase();
    final target = (exercise['target'] ?? exercise['category'] ?? exercise['targetMuscle'] ?? '').toString().toLowerCase();

    if (cat.isEmpty || cat == 'all') return true;

    // CARDIO: STRICT BAN on ordinary resistance exercises!
    if (cat == 'cardio') {
      if (_cardioForbiddenResistanceKeywords.any((k) => name.contains(k))) {
        return false;
      }
      final isKnownCardio = _cardioKeywords.any((k) => name.contains(k) || target.contains(k));
      final isCardioTarget = target.contains('cardio') || target.contains('aerobic') || target.contains('conditioning');
      final isTimedCardio = (exercise['durationSeconds'] is num && (exercise['durationSeconds'] as num) > 0) &&
          !name.contains('press') && !name.contains('row') && !name.contains('curl');
      return isKnownCardio || isCardioTarget || isTimedCardio;
    }

    // HIIT: Conditioning or interval movements
    if (cat == 'hiit') {
      return _hiitKeywords.any((k) => name.contains(k)) ||
             _cardioKeywords.any((k) => name.contains(k)) ||
             target.contains('hiit') || target.contains('cardio') || target.contains('conditioning') ||
             name.contains('jump') || name.contains('burpee');
    }

    // CHEST
    if (cat == 'chest') {
      return _chestKeywords.any((k) => name.contains(k) || target.contains(k)) ||
             target.contains('chest') || target.contains('pectoral');
    }

    // BACK
    if (cat == 'back') {
      return _backKeywords.any((k) => name.contains(k) || target.contains(k)) ||
             target.contains('back') || target.contains('lat') || target.contains('trap') || target.contains('rhomboid');
    }

    // ARMS
    if (cat == 'arms') {
      return _armsKeywords.any((k) => name.contains(k) || target.contains(k)) ||
             target.contains('arm') || target.contains('bicep') || target.contains('tricep') || target.contains('forearm');
    }

    // SHOULDERS
    if (cat == 'shoulders') {
      return _shouldersKeywords.any((k) => name.contains(k) || target.contains(k)) ||
             target.contains('shoulder') || target.contains('delt');
    }

    // LEGS
    if (cat == 'legs') {
      return _legsKeywords.any((k) => name.contains(k) || target.contains(k)) ||
             target.contains('leg') || target.contains('quad') || target.contains('hamstring') ||
             target.contains('glute') || target.contains('calf');
    }

    // CORE
    if (cat == 'core') {
      return _coreKeywords.any((k) => name.contains(k) || target.contains(k)) ||
             target.contains('core') || target.contains('ab') || target.contains('waist') || target.contains('oblique');
    }

    // PUSH: Chest + Shoulders + Triceps
    if (cat == 'push') {
      final isChest = _chestKeywords.any((k) => name.contains(k) || target.contains(k)) || target.contains('chest');
      final isShoulder = _shouldersKeywords.any((k) => name.contains(k) || target.contains(k)) || target.contains('shoulder') || target.contains('delt');
      final isTricep = name.contains('tricep') || target.contains('tricep') || name.contains('dip');
      return isChest || isShoulder || isTricep;
    }

    // PULL: Back + Biceps + Rear Delts / Forearms
    if (cat == 'pull') {
      final isBack = _backKeywords.any((k) => name.contains(k) || target.contains(k)) || target.contains('back') || target.contains('lat');
      final isBicep = name.contains('bicep') || target.contains('bicep') || name.contains('curl');
      final isRearDelt = name.contains('rear delt') || target.contains('rear delt') || name.contains('face pull');
      return isBack || isBicep || isRearDelt;
    }

    // UPPER BODY: Chest + Back + Shoulders + Arms
    if (cat == 'upper body' || cat == 'upper') {
      final isChest = _chestKeywords.any((k) => name.contains(k) || target.contains(k)) || target.contains('chest');
      final isBack = _backKeywords.any((k) => name.contains(k) || target.contains(k)) || target.contains('back');
      final isShoulder = _shouldersKeywords.any((k) => name.contains(k) || target.contains(k)) || target.contains('shoulder');
      final isArm = _armsKeywords.any((k) => name.contains(k) || target.contains(k)) || target.contains('arm');
      return isChest || isBack || isShoulder || isArm;
    }

    // LOWER BODY: Quads + Hamstrings + Glutes + Calves
    if (cat == 'lower body' || cat == 'lower') {
      return _legsKeywords.any((k) => name.contains(k) || target.contains(k)) ||
             target.contains('leg') || target.contains('quad') || target.contains('hamstring') ||
             target.contains('glute') || target.contains('calf');
    }

    // FULL BODY: allows anything, but balanced validation is handled at routine level
    if (cat == 'full body') {
      return true;
    }

    return true;
  }

  // ─── EQUIPMENT COMPATIBILITY & REPAIR ────────────────────────────────────────

  /// Checks if an exercise's required equipment is compatible with user's equipment.
  static bool isEquipmentCompatible(String exEquipment, String exName, List<String> userEquipment) {
    final cleanAllowed = userEquipment
        .map((e) => e.trim().toLowerCase())
        .where((e) => e.isNotEmpty && e != 'none' && e != 'none / bodyweight' && e != 'bodyweight')
        .toList();

    // If user has full gym, barbell, or gym access, all equipment is allowed
    if (cleanAllowed.any((e) => e.contains('full gym') || e.contains('gym') || e.contains('barbell'))) {
      return true;
    }

    final eq = exEquipment.toLowerCase();
    final name = exName.toLowerCase();

    // Bodyweight only
    if (cleanAllowed.isEmpty) {
      if (eq.contains('barbell') || eq.contains('dumbbell') || eq.contains('cable') ||
          eq.contains('machine') || eq.contains('kettlebell') || eq.contains('smith') ||
          name.contains('barbell') || name.contains('dumbbell') || name.contains('cable') ||
          name.contains('bench press') || name.contains('leg press') || name.contains('hack squat')) {
        return false;
      }
      return true;
    }

    final hasDumbbells = cleanAllowed.any((e) => e.contains('dumbbell'));
    final hasCables = cleanAllowed.any((e) => e.contains('cable'));
    final hasMachines = cleanAllowed.any((e) => e.contains('machine'));

    if (!hasCables && (eq.contains('cable') || name.contains('cable') || name.contains('lat pulldown'))) {
      return false;
    }
    if (!hasMachines && (eq.contains('machine') || eq.contains('smith') || name.contains('leg press') || name.contains('hack squat'))) {
      return false;
    }
    if (!hasDumbbells && (eq.contains('dumbbell') || name.contains('dumbbell'))) {
      return false;
    }

    return true;
  }

  /// Deterministically repairs an exercise to fit available equipment.
  static Map<String, dynamic> repairEquipment(Map<String, dynamic> ex, List<String> userEquipment) {
    final cleanAllowed = userEquipment
        .map((e) => e.trim().toLowerCase())
        .where((e) => e.isNotEmpty && e != 'none' && e != 'none / bodyweight' && e != 'bodyweight')
        .toList();
    final hasDumbbells = cleanAllowed.any((e) => e.contains('dumbbell'));

    final copy = Map<String, dynamic>.from(ex);
    final name = (copy['name'] ?? copy['exerciseName'] ?? '').toString();
    final nameLow = name.toLowerCase();

    if (hasDumbbells) {
      if (nameLow.contains('squat') || nameLow.contains('leg press')) {
        copy['name'] = 'Dumbbell Goblet Squat';
        copy['equipment'] = 'Dumbbells';
      } else if (nameLow.contains('bench press') || nameLow.contains('chest press') || nameLow.contains('fly')) {
        copy['name'] = 'Dumbbell Bench Press';
        copy['equipment'] = 'Dumbbells';
      } else if (nameLow.contains('row') || nameLow.contains('pulldown')) {
        copy['name'] = 'Dumbbell Bent-Over Row';
        copy['equipment'] = 'Dumbbells';
      } else if (nameLow.contains('shoulder') || nameLow.contains('overhead')) {
        copy['name'] = 'Dumbbell Shoulder Press';
        copy['equipment'] = 'Dumbbells';
      } else if (nameLow.contains('curl') || nameLow.contains('bicep')) {
        copy['name'] = 'Dumbbell Bicep Curl';
        copy['equipment'] = 'Dumbbells';
      } else if (nameLow.contains('tricep') || nameLow.contains('pushdown')) {
        copy['name'] = 'Dumbbell Overhead Tricep Extension';
        copy['equipment'] = 'Dumbbells';
      } else {
        copy['equipment'] = 'Dumbbells';
      }
    } else {
      // Bodyweight only
      if (nameLow.contains('bench press') || nameLow.contains('chest') || nameLow.contains('fly') || nameLow.contains('press')) {
        copy['name'] = 'Push-Ups';
        copy['equipment'] = 'Bodyweight';
      } else if (nameLow.contains('squat') || nameLow.contains('leg press') || nameLow.contains('hack squat')) {
        copy['name'] = 'Bodyweight Air Squats';
        copy['equipment'] = 'Bodyweight';
      } else if (nameLow.contains('lunge')) {
        copy['name'] = 'Walking Lunges';
        copy['equipment'] = 'Bodyweight';
      } else if (nameLow.contains('row') || nameLow.contains('pulldown') || nameLow.contains('back')) {
        copy['name'] = 'Prone Back Extensions (Superman)';
        copy['equipment'] = 'Bodyweight';
      } else if (nameLow.contains('shoulder') || nameLow.contains('overhead')) {
        copy['name'] = 'Pike Push-Ups';
        copy['equipment'] = 'Bodyweight';
      } else if (nameLow.contains('tricep') || nameLow.contains('pushdown')) {
        copy['name'] = 'Chair / Bench Dips';
        copy['equipment'] = 'Bodyweight';
      } else if (nameLow.contains('curl') || nameLow.contains('bicep')) {
        copy['name'] = 'Doorframe Isometric Bicep Curl';
        copy['equipment'] = 'Bodyweight';
      } else {
        copy['name'] = 'Bodyweight Air Squats';
        copy['equipment'] = 'Bodyweight';
      }
    }
    copy['exerciseName'] = copy['name'];
    return copy;
  }

  // ─── FITNESS LEVEL ENFORCEMENT ──────────────────────────────────────────────

  static const Set<String> _advancedOnlyKeywords = {
    'barbell snatch', 'clean and jerk', 'muscle-up', 'muscle up', 'pistol squat',
    'handstand push-up', 'handstand push up', 'one-arm push-up', 'one-arm pull-up',
    'dragon flag', 'front lever', 'planche', 'heavy deficit deadlift',
  };

  /// Validates if an exercise is appropriate for the user's fitness level.
  static bool isFitnessLevelAppropriate(Map<String, dynamic> ex, String fitnessLevel) {
    final level = fitnessLevel.trim().toLowerCase();
    final name = (ex['name'] ?? ex['exerciseName'] ?? '').toString().toLowerCase();

    if (level.contains('beg')) {
      if (_advancedOnlyKeywords.any((k) => name.contains(k))) {
        return false;
      }
    }
    return true;
  }

  /// Repairs an advanced-only movement for beginners.
  static Map<String, dynamic> repairFitnessLevel(Map<String, dynamic> ex) {
    final copy = Map<String, dynamic>.from(ex);
    final name = (copy['name'] ?? copy['exerciseName'] ?? '').toString().toLowerCase();

    if (name.contains('pistol squat')) {
      copy['name'] = 'Assisted Bodyweight Squats';
    } else if (name.contains('muscle') || name.contains('one-arm pull')) {
      copy['name'] = 'Inverted Rows';
    } else if (name.contains('handstand') || name.contains('one-arm push')) {
      copy['name'] = 'Knee Push-Ups';
    } else {
      copy['name'] = 'Push-Ups';
    }
    copy['exerciseName'] = copy['name'];
    return copy;
  }

  // ─── REPLACEMENT LOOKUP ─────────────────────────────────────────────────────

  /// Fetches a valid replacement exercise from the canonical library.
  static Map<String, dynamic> getReplacementExercise({
    required String targetCategory,
    required List<String> availableEquipment,
    required Set<String> existingNormalizedNames,
  }) {
    final normCat = targetCategory.trim().toLowerCase();
    String lookupKey = normCat;

    if (normCat == 'push') lookupKey = 'chest';
    if (normCat == 'pull') lookupKey = 'back';
    if (normCat == 'upper body' || normCat == 'upper') lookupKey = 'chest';
    if (normCat == 'lower body' || normCat == 'lower') lookupKey = 'legs';

    final pool = _fallbackLibrary[lookupKey] ?? _fallbackLibrary['cardio']!;

    // First pass: try candidates matching equipment directly
    for (var candidate in pool) {
      final normName = normalizeExerciseName(candidate['name'].toString());
      if (existingNormalizedNames.contains(normName)) continue;

      final candEq = candidate['equipment'].toString();
      final candName = candidate['name'].toString();
      if (isEquipmentCompatible(candEq, candName, availableEquipment)) {
        return Map<String, dynamic>.from(candidate);
      }
    }

    // Second pass: try repaired candidates to find an unused one
    for (var candidate in pool) {
      final rep = repairEquipment(candidate, availableEquipment);
      final normName = normalizeExerciseName(rep['name'].toString());
      if (!existingNormalizedNames.contains(normName)) {
        return rep;
      }
    }

    // Fallback: return repaired first candidate with target stamped
    final fallback = repairEquipment(pool.first, availableEquipment);
    fallback['target'] = targetCategory;
    fallback['category'] = targetCategory;
    return fallback;
  }

  // ─── COMPREHENSIVE ROUTINE VALIDATOR & REPAIR ───────────────────────────────

  /// Deterministically validates and repairs a generated routine map.
  ///
  /// Guarantees:
  /// 1. Category correctness for all 13 categories (No resistance in Cardio!).
  /// 2. Equipment compatibility (Repairs unavailable items).
  /// 3. Fitness level safety (Repairs beginner violations).
  /// 4. Full Body balanced coverage (Upper Push + Upper Pull + Lower + Core).
  /// 5. No duplicates or alias duplicates within the routine.
  /// 6. Between 3 and 6 valid exercises.
  static Map<String, dynamic> validateAndRepairRoutine(
    Map<String, dynamic> rawRoutine, {
    String? requestedCategory,
    List<String> availableEquipment = const [],
    String fitnessLevel = 'Intermediate',
  }) {
    final routine = Map<String, dynamic>.from(rawRoutine);

    // Normalize routine category
    String routineCategory = requestedCategory?.trim().isNotEmpty == true && requestedCategory != 'All'
        ? requestedCategory!.trim()
        : (routine['category'] ?? 'Full Body').toString().trim();

    final lowerCat = routineCategory.toLowerCase();
    if (lowerCat == 'waist' || lowerCat == 'abs' || lowerCat == 'abdominals') {
      routineCategory = 'Core';
    }
    routine['category'] = routineCategory;

    final rawExercises = routine['exercises'];
    final List<Map<String, dynamic>> cleanList = [];

    if (rawExercises is List) {
      for (var e in rawExercises) {
        if (e is Map) {
          cleanList.add(Map<String, dynamic>.from(e));
        }
      }
    }

    final List<Map<String, dynamic>> validatedExercises = [];
    final Set<String> seenNormalizedNames = {};

    for (var ex in cleanList) {
      final name = (ex['name'] ?? ex['exerciseName'] ?? '').toString().trim();
      if (name.isEmpty) continue;

      final normName = normalizeExerciseName(name);

      // 1. Check duplicate / alias
      if (seenNormalizedNames.contains(normName)) {
        // Substitute duplicate
        final replacement = getReplacementExercise(
          targetCategory: routineCategory,
          availableEquipment: availableEquipment,
          existingNormalizedNames: seenNormalizedNames,
        );
        final repNorm = normalizeExerciseName(replacement['name'].toString());
        seenNormalizedNames.add(repNorm);
        validatedExercises.add(replacement);
        continue;
      }

      // 2. Category validation
      if (!isExerciseValidForCategory(ex, routineCategory)) {
        // Invalid for category -> Replace with valid equivalent!
        final replacement = getReplacementExercise(
          targetCategory: routineCategory,
          availableEquipment: availableEquipment,
          existingNormalizedNames: seenNormalizedNames,
        );
        final repNorm = normalizeExerciseName(replacement['name'].toString());
        seenNormalizedNames.add(repNorm);
        validatedExercises.add(replacement);
        continue;
      }

      // 3. Equipment validation
      Map<String, dynamic> processedEx = Map<String, dynamic>.from(ex);
      final exEq = (processedEx['equipment'] ?? 'Bodyweight').toString();
      if (!isEquipmentCompatible(exEq, name, availableEquipment)) {
        processedEx = repairEquipment(processedEx, availableEquipment);
      }

      // 4. Fitness level validation
      if (!isFitnessLevelAppropriate(processedEx, fitnessLevel)) {
        processedEx = repairFitnessLevel(processedEx);
      }

      // 5. Cardio timed-tracking enforcement
      if (routineCategory.toLowerCase() == 'cardio') {
        processedEx['target'] = 'Cardio';
        processedEx['category'] = 'Cardio';
        final dur = processedEx['durationSeconds'] ?? processedEx['duration'];
        if (dur == null || (dur is num && dur <= 0)) {
          processedEx['durationSeconds'] = 45;
          processedEx['sets'] = '3 sets x 45s';
        }
      }

      final finalNorm = normalizeExerciseName((processedEx['name'] ?? '').toString());
      seenNormalizedNames.add(finalNorm);
      validatedExercises.add(processedEx);
    }

    // 6. Full Body Coverage Balance Check
    if (routineCategory.toLowerCase() == 'full body') {
      _ensureFullBodyBalance(validatedExercises, availableEquipment, seenNormalizedNames);
    }

    // 7. Ensure minimum exercise count (between 3 and 6)
    while (validatedExercises.length < 3) {
      final rep = getReplacementExercise(
        targetCategory: routineCategory,
        availableEquipment: availableEquipment,
        existingNormalizedNames: seenNormalizedNames,
      );
      final repNorm = normalizeExerciseName(rep['name'].toString());
      seenNormalizedNames.add(repNorm);
      validatedExercises.add(rep);
    }

    // Cap at 6 exercises
    if (validatedExercises.length > 6) {
      validatedExercises.removeRange(6, validatedExercises.length);
    }

    routine['exercises'] = validatedExercises;
    return routine;
  }

  /// Ensures a Full Body routine has at least 1 Upper Push, 1 Upper Pull, 1 Lower, and 1 Core.
  static void _ensureFullBodyBalance(
    List<Map<String, dynamic>> exercises,
    List<String> availableEquipment,
    Set<String> seenNormalizedNames,
  ) {
    bool hasPush = false;
    bool hasPull = false;
    bool hasLower = false;
    bool hasCore = false;

    for (var ex in exercises) {
      final name = (ex['name'] ?? '').toString().toLowerCase();
      final target = (ex['target'] ?? '').toString().toLowerCase();

      if (_chestKeywords.any((k) => name.contains(k)) || _shouldersKeywords.any((k) => name.contains(k))) {
        hasPush = true;
      }
      if (_backKeywords.any((k) => name.contains(k)) || name.contains('curl') || target.contains('back')) {
        hasPull = true;
      }
      if (_legsKeywords.any((k) => name.contains(k)) || target.contains('leg') || target.contains('quad')) {
        hasLower = true;
      }
      if (_coreKeywords.any((k) => name.contains(k)) || target.contains('core') || target.contains('ab')) {
        hasCore = true;
      }
    }

    // Augment or replace missing essentials
    if (!hasPush) {
      final pushEx = getReplacementExercise(
        targetCategory: 'push',
        availableEquipment: availableEquipment,
        existingNormalizedNames: seenNormalizedNames,
      );
      seenNormalizedNames.add(normalizeExerciseName(pushEx['name'].toString()));
      exercises.add(pushEx);
    }
    if (!hasPull) {
      final pullEx = getReplacementExercise(
        targetCategory: 'pull',
        availableEquipment: availableEquipment,
        existingNormalizedNames: seenNormalizedNames,
      );
      seenNormalizedNames.add(normalizeExerciseName(pullEx['name'].toString()));
      exercises.add(pullEx);
    }
    if (!hasLower) {
      final lowerEx = getReplacementExercise(
        targetCategory: 'legs',
        availableEquipment: availableEquipment,
        existingNormalizedNames: seenNormalizedNames,
      );
      seenNormalizedNames.add(normalizeExerciseName(lowerEx['name'].toString()));
      exercises.add(lowerEx);
    }
    if (!hasCore) {
      final coreEx = getReplacementExercise(
        targetCategory: 'core',
        availableEquipment: availableEquipment,
        existingNormalizedNames: seenNormalizedNames,
      );
      seenNormalizedNames.add(normalizeExerciseName(coreEx['name'].toString()));
      exercises.add(coreEx);
    }
  }
}

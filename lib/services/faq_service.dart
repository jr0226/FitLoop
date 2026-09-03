import '../models/faq_item.dart';

/// Result object returned by the FaqService matching engine.
class FaqSearchResult {
  final FaqItem? bestMatch;
  final List<FaqItem> relatedMatches;
  final String answer;
  final bool isConfident;
  final bool isSafetyWarning;

  const FaqSearchResult({
    this.bestMatch,
    this.relatedMatches = const [],
    required this.answer,
    required this.isConfident,
    this.isSafetyWarning = false,
  });
}

/// Centralized Help & FAQ service containing the FitLoop knowledge base,
/// token/keyword matching, medical safety guardrails, and category browsing.
class FaqService {
  static const List<String> defaultSuggestedQuestions = [
    'How do I scan food?',
    'How do I generate a workout?',
    'How do I export my report?',
    'How do reminders work?',
    'How do I update my weight?',
    'Where is my data stored?',
  ];

  static const List<String> _medicalKeywords = [
    'chest pain',
    'heart attack',
    'stop medication',
    'stop medicine',
    'prescribed pills',
    'lose 10 kg in a week',
    'lose 10kg in a week',
    'lose 20 kg in a month',
    'lose 20kg in a month',
    'starve',
    'eating disorder',
    'suicide',
    'depressed diagnosis',
    'am i allergic',
    'severe allergic',
    'anaphylaxis',
    'trouble breathing',
    'fainting',
  ];

  static const Set<String> _stopWords = {
    'can', 'how', 'do', 'i', 'my', 'is', 'a', 'the', 'to', 'what', 'are', 'why',
    'fitloop', 'in', 'for', 'of', 'and', 'it', 'me', 'you', 'on', 'with', 'from',
    'about', 'this', 'an', 'at', 'by', 'be', 'or', 'so',
  };

  /// The master offline FAQ knowledge base.
  static const List<FaqItem> allFaqs = [
    // =========================================================================
    // 1. ACCOUNT
    // =========================================================================
    FaqItem(
      id: 'account_edit_profile',
      category: FaqCategory.account,
      question: 'How do I edit my profile?',
      answer:
          'Open Settings from the bottom navigation bar. Under "Account & Profile", tap on your name or demographic fields to edit your age, gender, height, and current weight.',
      navigationPath: 'Settings → Account & Profile',
      keywords: ['edit profile', 'change name', 'update profile', 'change height', 'change age', 'profile info'],
    ),
    FaqItem(
      id: 'account_change_goal',
      category: FaqCategory.account,
      question: 'How do I change my fitness goal?',
      answer:
          'Go to Settings → Biometrics & Targets → Fitness Goal. You can select Weight Loss, Muscle Gain, or Maintenance. Updating your goal automatically recalculates your target daily calories and macronutrient ratios.',
      navigationPath: 'Settings → Biometrics & Targets → Fitness Goal',
      keywords: ['fitness goal', 'change goal', 'muscle gain', 'weight loss', 'maintenance', 'target goal'],
    ),
    FaqItem(
      id: 'account_change_target_weight',
      category: FaqCategory.account,
      question: 'How do I change my target weight?',
      answer:
          'Navigate to Settings → Biometrics & Targets → Target Weight. Enter your new goal weight. FitLoop will automatically recalculate your recommended caloric targets and progress delta in your reports.',
      navigationPath: 'Settings → Biometrics & Targets → Target Weight',
      keywords: ['target weight', 'goal weight', 'change weight goal', 'weight target'],
    ),
    FaqItem(
      id: 'account_delete',
      category: FaqCategory.account,
      question: 'How do I delete my account?',
      answer:
          'Go to Settings, scroll to the bottom "Danger Zone", and tap "Delete Account". This permanently removes your authentication record and personal Firestore data. Note that this action cannot be undone.',
      navigationPath: 'Settings → Danger Zone → Delete Account',
      keywords: ['delete account', 'remove account', 'erase data', 'close account'],
    ),

    // =========================================================================
    // 2. SCAN FOOD
    // =========================================================================
    FaqItem(
      id: 'scan_food_how_to',
      category: FaqCategory.scanFood,
      question: 'How do I scan food?',
      answer:
          'Tap the center "Scan" button in the bottom navigation bar. Position your camera over your meal or select an existing photo from your gallery, then tap "Analyze Meal". FitLoop AI analyzes the visual elements and estimates calories, protein, carbs, fat, and a meal score.',
      navigationPath: 'Bottom Navigation → Center Scan Button',
      keywords: ['scan food', 'camera food', 'food scanner', 'take picture of food', 'photo food', 'ai food'],
    ),
    FaqItem(
      id: 'scan_food_multi',
      category: FaqCategory.scanFood,
      question: 'Can FitLoop detect multiple foods?',
      answer:
          'Yes! FitLoop AI detects composite plates containing multiple items (e.g. rice, chicken breast, and vegetables). In your food log and PDF report, the component food names are preserved and summarized cleanly (e.g. "Rice, Chicken, Sambal + 2 more").',
      navigationPath: 'Scan Food → Detected Items List',
      keywords: ['multiple foods', 'multi food', 'composite plate', 'several items', 'mixed meal'],
    ),
    FaqItem(
      id: 'scan_food_failure',
      category: FaqCategory.scanFood,
      question: 'Why did Scan Food fail?',
      answer:
          'Scan Food requires good lighting, a clear angle showing the entire plate, and an active internet connection to communicate with the AI model. If the photo is too blurry, dark, or not food, the AI may ask you to retry or log the meal manually from the Diet tab.',
      navigationPath: 'Diet → Log Meal (Manual Fallback)',
      keywords: ['scan failed', 'food error', 'cannot detect', 'blurry food', 'scan food error'],
    ),
    FaqItem(
      id: 'scan_food_meal_score',
      category: FaqCategory.scanFood,
      question: 'What does Meal Score mean?',
      answer:
          'Meal Score is a 0 to 100 nutritional quality rating assigned by FitLoop AI. It evaluates nutritional density, protein balance, healthy micronutrients, and alignment with your dietary goals and allergies.',
      navigationPath: 'Diet → Meal Details Sheet',
      keywords: ['meal score', 'nutrition score', 'score rating', 'quality rating'],
    ),
    FaqItem(
      id: 'scan_food_sources',
      category: FaqCategory.scanFood,
      question: 'Where does nutrition data come from?',
      answer:
          'Nutrition estimates are generated through advanced multimodal Gemini vision analysis calibrated against standard nutritional database standards (USDA / Malaysian Food Composition databases).',
      navigationPath: 'Scan Food / Diet Tab',
      keywords: ['nutrition data', 'calorie source', 'data source', 'where calories come from'],
    ),

    // =========================================================================
    // 3. DIET & MEALS
    // =========================================================================
    FaqItem(
      id: 'diet_manual_log',
      category: FaqCategory.diet,
      question: 'How do I manually log a meal?',
      answer:
          'Open the Diet tab from the bottom navigation bar and tap the "+" button or "Log Food". Search for items in the food database or enter custom calories, protein, carbs, and fat values directly.',
      navigationPath: 'Diet → Log Meal (+)',
      keywords: ['manual log', 'log food', 'add meal', 'manual food', 'search food'],
    ),
    FaqItem(
      id: 'diet_delete_meal',
      category: FaqCategory.diet,
      question: 'How do I delete a logged meal?',
      answer:
          'Navigate to the Diet tab, locate the meal card under today\'s timeline, swipe left or tap the meal card to open the detail sheet, and select "Delete Log".',
      navigationPath: 'Diet → Tap Meal Card → Delete',
      keywords: ['delete meal', 'remove food', 'cancel meal', 'delete food log'],
    ),
    FaqItem(
      id: 'diet_view_details',
      category: FaqCategory.diet,
      question: 'How do I view meal details?',
      answer:
          'Tap any meal card on your Diet timeline. A bottom sheet will slide up showing individual detected ingredients, macronutrient breakdowns, and nutritional tips.',
      navigationPath: 'Diet → Tap Meal Card',
      keywords: ['view meal', 'meal details', 'macronutrient breakdown', 'food breakdown'],
    ),
    FaqItem(
      id: 'diet_macros_meaning',
      category: FaqCategory.diet,
      question: 'What do calories and macros mean?',
      answer:
          'Calories measure overall energy. Protein repairs and builds muscle (4 kcal/g). Carbohydrates provide immediate energy for workouts (4 kcal/g). Fats support hormone production and nutrient absorption (9 kcal/g).',
      navigationPath: 'Diet → Macronutrient Progress Bars',
      keywords: ['macros', 'protein carbs fat', 'what are macros', 'macronutrients', 'calorie definition'],
    ),

    // =========================================================================
    // 4. WORKOUT
    // =========================================================================
    FaqItem(
      id: 'workout_generate',
      category: FaqCategory.workout,
      question: 'How do I generate a workout?',
      answer:
          'Go to the Workout tab and tap "AI Routine Generator". Choose your target muscle group, duration, and equipment. FitLoop AI creates a personalized routine tailored to your fitness level and equipment.',
      navigationPath: 'Workout → AI Routine Generator',
      keywords: ['generate workout', 'routine generator', 'ai workout', 'create routine', 'custom workout'],
    ),
    FaqItem(
      id: 'workout_personalization',
      category: FaqCategory.workout,
      question: 'How does FitLoop personalize workouts?',
      answer:
          'FitLoop analyzes your saved profile in Settings: Fitness Level (Beginner/Intermediate/Advanced), Available Equipment (Dumbbells, Barbells, Cable, Bodyweight), and Preferred Workout Types (Hypertrophy, Strength, HIIT, Calisthenics).',
      navigationPath: 'Settings → Training & Fitness',
      keywords: ['personalize workout', 'workout adaptation', 'tailored workout', 'profile workout'],
    ),
    FaqItem(
      id: 'workout_equipment_matter',
      category: FaqCategory.workout,
      question: 'Why does equipment matter?',
      answer:
          'Selecting your available equipment prevents FitLoop from generating exercises you cannot perform. If you only have dumbbells at home, FitLoop will only prescribe dumbbell or bodyweight movements.',
      navigationPath: 'Settings → Training & Fitness → Available Equipment',
      keywords: ['equipment', 'home gym', 'dumbbells only', 'no equipment', 'available equipment'],
    ),
    FaqItem(
      id: 'workout_start',
      category: FaqCategory.workout,
      question: 'How do I start a workout?',
      answer:
          'From the Workout tab, select today\'s routine or any generated routine, and tap "Start Workout". Use the interactive set tracker to check off completed sets and log lifted weights.',
      navigationPath: 'Workout → Routine Card → Start Workout',
      keywords: ['start workout', 'track sets', 'log weights', 'begin workout'],
    ),
    FaqItem(
      id: 'workout_calories_burned',
      category: FaqCategory.workout,
      question: 'How are calories burned calculated?',
      answer:
          'FitLoop uses metabolic equivalent (MET) formulas based on workout intensity, session duration, and your body weight to calculate realistic calories burned.',
      navigationPath: 'Workout Summary / Reports',
      keywords: ['calories burned', 'workout calories', 'how calories burned calculated', 'met formula'],
    ),

    // =========================================================================
    // 5. EXERCISE LIBRARY
    // =========================================================================
    FaqItem(
      id: 'exercise_search',
      category: FaqCategory.exerciseLibrary,
      question: 'How do I search exercises?',
      answer:
          'In the Workout tab, tap "Exercise Library" at the top. You can search by exercise name, filter by target muscle (Chest, Back, Legs, Shoulders, Arms, Core), or filter by equipment.',
      navigationPath: 'Workout → Exercise Library',
      keywords: ['search exercises', 'find exercise', 'exercise library', 'browse exercises'],
    ),
    FaqItem(
      id: 'exercise_gifs',
      category: FaqCategory.exerciseLibrary,
      question: 'Where do exercise GIFs come from?',
      answer:
          'Exercise demonstrations and form animations come from the integrated ExerciseDB database, providing reliable visual movement guides for proper technique.',
      navigationPath: 'Workout → Exercise Library → Exercise Detail',
      keywords: ['exercise gif', 'animations', 'form demo', 'exercise video'],
    ),
    FaqItem(
      id: 'exercise_unavailable',
      category: FaqCategory.exerciseLibrary,
      question: 'Why is an exercise not available?',
      answer:
          'If an exercise is filtered out of your routine generator, check your Available Equipment in Settings. If you have "Dumbbells Only" selected, barbell or cable movements will be omitted.',
      navigationPath: 'Settings → Training & Fitness → Available Equipment',
      keywords: ['exercise missing', 'cannot find exercise', 'exercise unavailable'],
    ),

    // =========================================================================
    // 6. PROGRESS & BODY MEASUREMENTS
    // =========================================================================
    FaqItem(
      id: 'progress_log_weight',
      category: FaqCategory.progress,
      question: 'How do I log my weight?',
      answer:
          'Open the Progress tab and tap "+ Record Weight" or "Log Measurement". Enter today\'s weight and save. Your historical chart and goal delta will immediately update.',
      navigationPath: 'Progress → + Record Weight',
      keywords: ['log weight', 'record weight', 'enter weight', 'track weight', 'update weight'],
    ),
    FaqItem(
      id: 'progress_body_measurements',
      category: FaqCategory.progress,
      question: 'How do I add body measurements?',
      answer:
          'In the Progress tab, tap "Body Measurements". You can log waist circumference, body fat percentage, chest, arms, and hip measurements to track non-scale victories.',
      navigationPath: 'Progress → Body Measurements',
      keywords: ['body measurements', 'waist size', 'body fat', 'measurements', 'tape measure'],
    ),
    FaqItem(
      id: 'progress_target_weight_works',
      category: FaqCategory.progress,
      question: 'How does target weight work?',
      answer:
          'Target weight represents your goal. FitLoop calculates whether you are above or below target, displays net period change, and indicates remaining progress in your Health Report.',
      navigationPath: 'Progress Tab / Settings → Target Weight',
      keywords: ['target weight works', 'goal progress', 'weight delta', 'weight progress'],
    ),
    FaqItem(
      id: 'progress_view_history',
      category: FaqCategory.progress,
      question: 'How do I view weight progress?',
      answer:
          'The Progress tab displays interactive charts showing 7-day, 30-day, or all-time weight progression, along with net weight lost or gained.',
      navigationPath: 'Progress → Weight Trend Chart',
      keywords: ['view progress', 'weight history', 'weight graph', 'progress chart'],
    ),

    // =========================================================================
    // 7. NOTIFICATIONS & REMINDERS
    // =========================================================================
    FaqItem(
      id: 'notifications_enable',
      category: FaqCategory.notifications,
      question: 'How do I enable workout reminders?',
      answer:
          'Go to Settings → Notifications & Reminders. Enable the master notifications toggle, then turn on "Workout Reminder" and select your preferred reminder time.',
      navigationPath: 'Settings → Notifications & Reminders → Workout Reminder',
      keywords: ['enable notifications', 'workout reminder', 'schedule reminder', 'set notification'],
    ),
    FaqItem(
      id: 'notifications_troubleshoot',
      category: FaqCategory.notifications,
      question: 'Why did my reminder not appear?',
      answer:
          'Ensure Android notification permissions are granted. In Android System Settings → Apps → FitLoop → Battery, set battery optimization to "Unrestricted" so Android doesn\'t suppress background alarms.',
      navigationPath: 'Settings → Notifications & Reminders → Send Immediate Test',
      keywords: ['reminder not appearing', 'notification not working', 'alarm failed', 'battery optimization'],
    ),
    FaqItem(
      id: 'notifications_hydration',
      category: FaqCategory.notifications,
      question: 'How do hydration reminders work?',
      answer:
          'In Settings → Notifications & Reminders → Hydration Reminder, choose your interval (Every 2h, 3h, or 4h). FitLoop will remind you to drink water between 8:00 AM and 10:00 PM.',
      navigationPath: 'Settings → Notifications & Reminders → Hydration Reminder',
      keywords: ['hydration reminder', 'drink water reminder', 'water alert', 'hydration interval'],
    ),
    FaqItem(
      id: 'notifications_change_time',
      category: FaqCategory.notifications,
      question: 'How do I change reminder time?',
      answer:
          'Tap the clock button next to any reminder in Settings → Notifications & Reminders (e.g. Breakfast, Lunch, Dinner, or Workout) and pick a new time with the time picker.',
      navigationPath: 'Settings → Notifications & Reminders → Time Picker',
      keywords: ['change reminder time', 'update alarm', 'edit notification time'],
    ),

    // =========================================================================
    // 8. PDF REPORTS
    // =========================================================================
    FaqItem(
      id: 'reports_export_pdf',
      category: FaqCategory.reports,
      question: 'How do I export a PDF report?',
      answer:
          'Go to Settings → Data & Reports → Export Health & Fitness Report. Choose your date range (Last 7 Days, Last 30 Days, or Custom Range) and tap "Generate & Preview PDF".',
      navigationPath: 'Settings → Data & Reports → Export Health & Fitness Report',
      keywords: ['export pdf', 'download report', 'generate pdf', 'pdf report', 'share report'],
    ),
    FaqItem(
      id: 'reports_content',
      category: FaqCategory.reports,
      question: 'What data is included in the report?',
      answer:
          'The report includes your Profile Overview, Nutrition Summary (meals, macros, 30-day calorie trend), Workout Performance (volume, exercises, session history), Body Progression (weight delta, composition), and Unlocked Achievements.',
      navigationPath: 'Settings → Data & Reports',
      keywords: ['report content', 'what is in report', 'pdf data', 'nutrition report'],
    ),
    FaqItem(
      id: 'reports_share',
      category: FaqCategory.reports,
      question: 'Can I share the report?',
      answer:
          'Yes! From the PDF preview screen, tap the share icon in the top app bar to send your PDF via WhatsApp, Email, AirDrop/Nearby Share, or save it to your device storage.',
      navigationPath: 'Health Report Screen → Top App Bar Share Icon',
      keywords: ['share pdf', 'send report', 'print report', 'save pdf'],
    ),

    // =========================================================================
    // 9. SETTINGS
    // =========================================================================
    FaqItem(
      id: 'settings_fitness_level',
      category: FaqCategory.settings,
      question: 'What does Fitness Level do?',
      answer:
          'Fitness Level (Beginner, Intermediate, Advanced) determines the complexity and training volume of AI routines. Beginners receive foundational compound movements, while Advanced athletes receive higher sets and intensifiers.',
      navigationPath: 'Settings → Training & Fitness → Fitness Level',
      keywords: ['fitness level', 'beginner intermediate advanced', 'experience level'],
    ),
    FaqItem(
      id: 'settings_equipment',
      category: FaqCategory.settings,
      question: 'What does Available Equipment do?',
      answer:
          'It instructs the workout engine which gear you own (Barbells, Dumbbells, Cables, Pull-Up Bar, Kettlebells, or Bodyweight Only) so your generated workouts match your setup.',
      navigationPath: 'Settings → Training & Fitness → Available Equipment',
      keywords: ['available equipment', 'gym equipment', 'home gear', 'equipment setting'],
    ),
    FaqItem(
      id: 'settings_workout_types',
      category: FaqCategory.settings,
      question: 'What are Preferred Workout Types?',
      answer:
          'Preferred Workout Types (Hypertrophy, Strength, HIIT, Calisthenics, Cardio) tell the AI engine which training style to prioritize when generating routines.',
      navigationPath: 'Settings → Training & Fitness → Preferred Workout Types',
      keywords: ['preferred workout types', 'hypertrophy', 'strength', 'hiit', 'training style'],
    ),
    FaqItem(
      id: 'settings_diet_preference',
      category: FaqCategory.settings,
      question: 'What does Diet Preference do?',
      answer:
          'Diet Preference (Standard, High Protein, Keto, Vegetarian, Vegan) adjusts your daily macronutrient ratios and shapes AI meal suggestions to align with your eating habits.',
      navigationPath: 'Settings → Nutrition & Dietary Preferences → Diet Preference',
      keywords: ['diet preference', 'keto', 'vegan', 'vegetarian', 'high protein'],
    ),
    FaqItem(
      id: 'settings_allergies',
      category: FaqCategory.settings,
      question: 'What are Allergies & Intolerances used for?',
      answer:
          'Allergies (e.g. Peanuts, Dairy, Gluten, Shellfish) are passed into AI meal evaluations. If a scanned food contains ingredients you are allergic to, FitLoop AI flags it with a health warning.',
      navigationPath: 'Settings → Nutrition & Dietary Preferences → Allergies & Intolerances',
      keywords: ['allergies', 'intolerances', 'peanuts dairy gluten', 'allergy warning'],
    ),

    // =========================================================================
    // 10. PRIVACY & DATA
    // =========================================================================
    FaqItem(
      id: 'privacy_storage',
      category: FaqCategory.privacy,
      question: 'Where is my data stored?',
      answer:
          'Your data is stored in your private, authenticated Firebase Firestore database partition. It is protected by Firebase Security Rules ensuring only your logged-in account can read or write your logs.',
      navigationPath: 'Privacy & Security Standards',
      keywords: ['data stored', 'firebase storage', 'where is data', 'database security'],
    ),
    FaqItem(
      id: 'privacy_api_keys',
      category: FaqCategory.privacy,
      question: 'Are API keys stored in the app?',
      answer:
          'No! Sensitive API keys are strictly maintained on the secure backend server. The Flutter app communicates exclusively through authenticated HTTPS endpoints.',
      navigationPath: 'Architecture Security',
      keywords: ['api keys', 'security keys', 'stored in app', 'secret keys'],
    ),
    FaqItem(
      id: 'privacy_pdf_uploaded',
      category: FaqCategory.privacy,
      question: 'Is my PDF uploaded anywhere?',
      answer:
          'No. Your Health & Fitness PDF report is generated 100% locally on your device in memory. It is never uploaded to any third-party cloud server.',
      navigationPath: 'Settings → Data & Reports',
      keywords: ['pdf uploaded', 'cloud upload', 'pdf privacy', 'local pdf'],
    ),
    FaqItem(
      id: 'privacy_other_users',
      category: FaqCategory.privacy,
      question: 'Can other users see my data?',
      answer:
          'No. FitLoop does not have public profiles or open social feeds. All your workouts, meals, and body metrics are strictly private to your authenticated account.',
      navigationPath: 'Privacy & Security',
      keywords: ['other users see data', 'is my profile public', 'privacy', 'private data'],
    ),
  ];

  /// Checks whether a query contains clinical or emergency medical keywords.
  static bool isMedicalOrSafetyQuery(String query) {
    final lower = query.toLowerCase();
    for (final kw in _medicalKeywords) {
      if (lower.contains(kw)) {
        return true;
      }
    }
    return false;
  }

  /// Finds all FAQs matching a specific category.
  static List<FaqItem> getFaqsByCategory(FaqCategory category) {
    return allFaqs.where((f) => f.category == category).toList();
  }

  /// Searches the FAQ repository using weighted keyword and token matching.
  static FaqSearchResult search(String userQuery) {
    final query = userQuery.trim();
    if (query.isEmpty) {
      return const FaqSearchResult(
        answer: 'Please type a question or choose one of the suggested topics below.',
        isConfident: false,
      );
    }

    // 1. Safety / Medical check
    if (isMedicalOrSafetyQuery(query)) {
      return const FaqSearchResult(
        answer:
            'Important Health Notice: FitLoop is designed for fitness and general wellness tracking only and cannot provide medical advice, diagnosis, or clinical recommendations.\n\nIf you are experiencing severe symptoms, chest pain, an allergic reaction, or considering altering prescribed medication, please contact emergency medical services or consult a licensed physician immediately.',
        isConfident: true,
        isSafetyWarning: true,
      );
    }

    // 2. Normalize and tokenize query
    final lowerQuery = query.toLowerCase();
    final tokens = lowerQuery
        .replaceAll(RegExp(r'[^\w\s]'), '')
        .split(RegExp(r'\s+'))
        .where((t) => t.length > 1 && !_stopWords.contains(t))
        .toList();

    FaqItem? bestMatch;
    int highestScore = 0;
    final Map<FaqItem, int> scoredFaqs = {};

    for (final faq in allFaqs) {
      int score = 0;
      final faqQuestionLower = faq.question.toLowerCase();

      // Exact title match or substring match
      if (faqQuestionLower == lowerQuery) {
        score += 120;
      } else if (faqQuestionLower.contains(lowerQuery) || (tokens.length >= 3 && lowerQuery.contains(faqQuestionLower))) {
        score += 80;
      }

      // Keyword matches
      for (final kw in faq.keywords) {
        final kwLower = kw.toLowerCase();
        if (lowerQuery == kwLower) {
          score += 60;
        } else if (lowerQuery.contains(kwLower)) {
          score += 40;
        } else {
          // Token overlap within keyword
          for (final token in tokens) {
            if (kwLower.contains(token)) {
              score += 12;
            }
          }
        }
      }

      // Question token matches
      for (final token in tokens) {
        if (faqQuestionLower.contains(token)) {
          score += 15;
        }
      }

      if (score > 0) {
        scoredFaqs[faq] = score;
        if (score > highestScore) {
          highestScore = score;
          bestMatch = faq;
        }
      }
    }

    // Confident match threshold is 30
    if (highestScore >= 30 && bestMatch != null) {
      final related = scoredFaqs.keys
          .where((f) => f.id != bestMatch!.id)
          .take(3)
          .toList();

      final answerText = StringBuffer(bestMatch.answer);
      if (bestMatch.navigationPath != null) {
        answerText.write('\n\nNavigation: ${bestMatch.navigationPath}');
      }

      return FaqSearchResult(
        bestMatch: bestMatch,
        relatedMatches: related,
        answer: answerText.toString(),
        isConfident: true,
      );
    }

    // Safe fallback when no match is found
    return const FaqSearchResult(
      answer:
          "I couldn't find an exact FitLoop help article for that question.\n\nTry asking about Scan Food, workouts, progress, reminders, reports, or settings, or tap one of the suggested topics below.",
      isConfident: false,
    );
  }
}

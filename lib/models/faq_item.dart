/// Supported categories for FitLoop Help & FAQ knowledge base.
enum FaqCategory {
  account,
  scanFood,
  diet,
  workout,
  exerciseLibrary,
  progress,
  notifications,
  reports,
  settings,
  privacy,
}

extension FaqCategoryExtension on FaqCategory {
  String get displayName {
    switch (this) {
      case FaqCategory.account:
        return 'Account';
      case FaqCategory.scanFood:
        return 'Scan Food';
      case FaqCategory.diet:
        return 'Diet & Meals';
      case FaqCategory.workout:
        return 'Workout';
      case FaqCategory.exerciseLibrary:
        return 'Exercise Library';
      case FaqCategory.progress:
        return 'Progress & Body';
      case FaqCategory.notifications:
        return 'Reminders';
      case FaqCategory.reports:
        return 'PDF Reports';
      case FaqCategory.settings:
        return 'Settings';
      case FaqCategory.privacy:
        return 'Privacy & Data';
    }
  }

  String get iconName {
    switch (this) {
      case FaqCategory.account:
        return 'person';
      case FaqCategory.scanFood:
        return 'camera_alt';
      case FaqCategory.diet:
        return 'restaurant';
      case FaqCategory.workout:
        return 'fitness_center';
      case FaqCategory.exerciseLibrary:
        return 'menu_book';
      case FaqCategory.progress:
        return 'show_chart';
      case FaqCategory.notifications:
        return 'notifications_active';
      case FaqCategory.reports:
        return 'picture_as_pdf';
      case FaqCategory.settings:
        return 'tune';
      case FaqCategory.privacy:
        return 'security';
    }
  }
}

/// Represents a single FAQ knowledge item with navigation hints and search keywords.
class FaqItem {
  final String id;
  final FaqCategory category;
  final String question;
  final String answer;
  final List<String> keywords;
  final String? navigationPath;

  const FaqItem({
    required this.id,
    required this.category,
    required this.question,
    required this.answer,
    required this.keywords,
    this.navigationPath,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'category': category.name,
        'question': question,
        'answer': answer,
        'keywords': keywords,
        if (navigationPath != null) 'navigationPath': navigationPath,
      };

  factory FaqItem.fromJson(Map<String, dynamic> json) {
    return FaqItem(
      id: json['id'] as String,
      category: FaqCategory.values.firstWhere(
        (c) => c.name == json['category'],
        orElse: () => FaqCategory.settings,
      ),
      question: json['question'] as String,
      answer: json['answer'] as String,
      keywords: List<String>.from(json['keywords'] ?? []),
      navigationPath: json['navigationPath'] as String?,
    );
  }
}

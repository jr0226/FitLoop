import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/models/faq_item.dart';
import 'package:flutter_application_1/services/faq_service.dart';

void main() {
  group('FaqService Knowledge Base & Matching', () {
    test('Knowledge base covers all 10 categories', () {
      expect(FaqService.allFaqs.isNotEmpty, isTrue);

      final categoriesInFaqs = FaqService.allFaqs.map((f) => f.category).toSet();
      for (final cat in FaqCategory.values) {
        expect(
          categoriesInFaqs.contains(cat),
          isTrue,
          reason: 'Missing FAQs for category ${cat.name}',
        );
      }
    });

    test('Exact FAQ question match returns confident result', () {
      final res = FaqService.search('How do I scan food?');
      expect(res.isConfident, isTrue);
      expect(res.bestMatch, isNotNull);
      expect(res.bestMatch!.id, equals('scan_food_how_to'));
      expect(res.answer, contains('Scan'));
      expect(res.answer, contains('Navigation:'));
    });

    test('Case-insensitive and trimmed query matching works', () {
      final res = FaqService.search('   HOW DO I GENERATE A WORKOUT?   ');
      expect(res.isConfident, isTrue);
      expect(res.bestMatch, isNotNull);
      expect(res.bestMatch!.id, equals('workout_generate'));
      expect(res.answer, contains('AI Routine Generator'));
    });

    test('Keyword search matches target FAQs accurately', () {
      // "target weight"
      final resWeight = FaqService.search('change target weight');
      expect(resWeight.isConfident, isTrue);
      expect(resWeight.bestMatch?.id, equals('account_change_target_weight'));

      // "export pdf"
      final resPdf = FaqService.search('how to export pdf');
      expect(resPdf.isConfident, isTrue);
      expect(resPdf.bestMatch?.id, equals('reports_export_pdf'));

      // "hydration reminder"
      final resHydration = FaqService.search('water reminder interval');
      expect(resHydration.isConfident, isTrue);
      expect(resHydration.bestMatch?.id, equals('notifications_hydration'));

      // "data stored"
      final resPrivacy = FaqService.search('where is my data stored?');
      expect(resPrivacy.isConfident, isTrue);
      expect(resPrivacy.bestMatch?.id, equals('privacy_storage'));
    });

    test('Category filter returns correct subset of FAQs', () {
      final scanFaqs = FaqService.getFaqsByCategory(FaqCategory.scanFood);
      expect(scanFaqs.length, greaterThanOrEqualTo(4));
      for (final f in scanFaqs) {
        expect(f.category, equals(FaqCategory.scanFood));
      }

      final reportFaqs = FaqService.getFaqsByCategory(FaqCategory.reports);
      expect(reportFaqs.length, greaterThanOrEqualTo(3));
      for (final f in reportFaqs) {
        expect(f.category, equals(FaqCategory.reports));
      }
    });

    test('Medical and clinical emergency queries trigger safety disclaimer', () {
      final resChestPain = FaqService.search('I have severe chest pain during bench press');
      expect(resChestPain.isSafetyWarning, isTrue);
      expect(resChestPain.isConfident, isTrue);
      expect(resChestPain.answer, contains('Important Health Notice'));
      expect(resChestPain.answer, contains('licensed physician immediately'));

      final resMed = FaqService.search('Can I stop medication while dieting?');
      expect(resMed.isSafetyWarning, isTrue);
      expect(resMed.answer, contains('Important Health Notice'));

      final resExtreme = FaqService.search('How to lose 10 kg in a week?');
      expect(resExtreme.isSafetyWarning, isTrue);
      expect(resExtreme.answer, contains('Important Health Notice'));
    });

    test('Unknown questions trigger safe fallback response', () {
      final resUnknown = FaqService.search('Can FitLoop book a flight to Tokyo?');
      expect(resUnknown.isConfident, isFalse);
      expect(resUnknown.bestMatch, isNull);
      expect(resUnknown.answer, contains("I couldn't find an exact FitLoop help article"));
    });

    test('Empty or whitespace-only queries are handled safely', () {
      final resEmpty = FaqService.search('   ');
      expect(resEmpty.isConfident, isFalse);
      expect(resEmpty.answer, contains('Please type a question'));
    });

    test('Default suggested questions list contains key core topics', () {
      expect(FaqService.defaultSuggestedQuestions.length, greaterThanOrEqualTo(5));
      expect(FaqService.defaultSuggestedQuestions, contains('How do I scan food?'));
      expect(FaqService.defaultSuggestedQuestions, contains('How do I generate a workout?'));
      expect(FaqService.defaultSuggestedQuestions, contains('How do I export my report?'));
    });
  });
}

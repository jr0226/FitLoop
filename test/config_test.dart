import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/config/app_config.dart';

void main() {
  group('AppConfig Security & Configuration Tests', () {
    test('default apiBaseUrl is initialized properly', () {
      expect(AppConfig.apiBaseUrl, isNotEmpty);
      expect(AppConfig.requestTimeoutSeconds, equals(90));
    });

    test('default environment is development', () {
      expect(AppConfig.environment, equals('development'));
    });
  });
}

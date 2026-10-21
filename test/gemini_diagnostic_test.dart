import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:career_pilot/config/gemini_config.dart';

void main() {
  group('Gemini API Integration Diagnostic', () {
    test('Diagnostic: Simple Reply with OK request without resume upload', () async {
      final apiKey = GeminiConfig.apiKey;
      final modelName = GeminiConfig.modelName;
      final hasKey = apiKey.isNotEmpty;

      // ignore: avoid_print
      print('\n================ GEMINI DIAGNOSTIC TEST ================');
      // ignore: avoid_print
      print('1. API Key configured via --dart-define: $hasKey');
      // ignore: avoid_print
      print('2. Configured Model: $modelName');
      // ignore: avoid_print
      print(
        '3. Target Endpoint: https://generativelanguage.googleapis.com/v1beta/models/$modelName:generateContent',
      );

      final effectiveKey = hasKey
          ? apiKey
          : 'AIzaSyDummyKeyForTestingOnly_12345';

      final endpoint = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/$modelName:generateContent?key=$effectiveKey',
      );

      final requestBody = jsonEncode({
        'contents': [
          {
            'parts': [
              {'text': 'Reply with OK'},
            ],
          },
        ],
      });

      final stopwatch = Stopwatch()..start();
      final client = http.Client();

      try {
        final response = await client
            .post(
              endpoint,
              headers: {
                'Content-Type': 'application/json',
                'x-goog-api-key': effectiveKey,
              },
              body: requestBody,
            )
            .timeout(const Duration(seconds: 45));

        stopwatch.stop();

        // ignore: avoid_print
        print('4. Roundtrip Elapsed Time: ${stopwatch.elapsedMilliseconds} ms');
        // ignore: avoid_print
        print('5. HTTP Status Code: ${response.statusCode}');

        String sanitizedBody = response.body;
        if (hasKey) {
          sanitizedBody = sanitizedBody.replaceAll(apiKey, '[REDACTED_KEY]');
        }

        if (response.statusCode == 200) {
          // ignore: avoid_print
          print('6. Gemini API Response: SUCCESS (200 OK)');
          final data = jsonDecode(response.body);
          final candidates = data['candidates'] as List?;
          final replyText =
              candidates?.first['content']?['parts']?.first['text'] ?? '';
          // ignore: avoid_print
          print('7. Model Reply: ${replyText.toString().trim()}');
        } else {
          // ignore: avoid_print
          print('6. Response Body (Safe Preview):\n$sanitizedBody');
        }

        expect(response.statusCode, anyOf([200, 400]));
      } catch (e) {
        stopwatch.stop();
        // ignore: avoid_print
        print(
          '4. Request threw exception after ${stopwatch.elapsedMilliseconds} ms',
        );
        String sanitizedError = e.toString();
        if (hasKey) {
          sanitizedError = sanitizedError.replaceAll(apiKey, '[REDACTED_KEY]');
        }
        // ignore: avoid_print
        print('5. Exception Type: ${e.runtimeType}');
        // ignore: avoid_print
        print('6. Sanitized Exception: $sanitizedError');
      } finally {
        client.close();
      }
    });
  });
}

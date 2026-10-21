import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:career_pilot/config/gemini_config.dart';
import 'package:career_pilot/services/gemini_service.dart';

void main() {
  const sampleSuccessJson = '''
{
  "score": 85,
  "strengths": ["Strong Flutter experience", "Clean architecture"],
  "weaknesses": ["Needs more CI/CD details"],
  "demonstratedSkills": ["Flutter", "Dart", "Firebase"],
  "missingSkills": ["Docker", "Kubernetes"],
  "atsFeedback": "Standard headings and good keyword density.",
  "improvementSuggestions": ["Quantify impact in bullet points."]
}
''';

  final sampleGemini200Body = jsonEncode({
    'candidates': [
      {
        'content': {
          'parts': [
            {'text': sampleSuccessJson},
          ],
        },
      },
    ],
  });

  setUp(() {
    GeminiConfig.setRuntimeApiKey('test_valid_api_key_for_unit_tests');
    GeminiConfig.clearRuntimeModel();
  });

  tearDown(() {
    GeminiConfig.clearRuntimeApiKey();
    GeminiConfig.clearRuntimeModel();
  });

  group('GeminiService Exponential Backoff & Retry Tests', () {
    test(
      'retries on transient 503 high demand error and succeeds when next attempt is 200 OK',
      () async {
        int callCount = 0;
        final delays = <Duration>[];

        final mockClient = MockClient((request) async {
          callCount++;
          if (callCount == 1) {
            // First attempt: 503 high demand overload
            return http.Response(
              jsonEncode({
                'error': {
                  'code': 503,
                  'message':
                      'This model is currently experiencing high demand. Spikes in demand are usually temporary. Please try again later.',
                  'status': 'UNAVAILABLE',
                },
              }),
              503,
              headers: {'content-type': 'application/json'},
            );
          }
          // Second attempt: 200 OK success
          return http.Response(
            sampleGemini200Body,
            200,
            headers: {'content-type': 'application/json'},
          );
        });

        final service = GeminiService(
          client: mockClient,
          maxRetries: 3,
          delayFn: (d) async => delays.add(d),
        );

        final result = await service.analyzeResume(
          'Experienced Flutter Developer',
        );

        expect(callCount, 2);
        expect(delays.length, 1);
        expect(delays.first.inMilliseconds, greaterThanOrEqualTo(750));
        expect(result.score, 85);
        expect(result.strengths, contains('Strong Flutter experience'));
      },
    );

    test(
      'retries on transient 429 quota/rate limit error and succeeds on subsequent attempt',
      () async {
        int callCount = 0;
        final delays = <Duration>[];

        final mockClient = MockClient((request) async {
          callCount++;
          if (callCount < 3) {
            // First 2 attempts: 429 rate limit
            return http.Response(
              jsonEncode({
                'error': {
                  'code': 429,
                  'message': 'Resource has been exhausted (e.g. check quota).',
                  'status': 'RESOURCE_EXHAUSTED',
                },
              }),
              429,
              headers: {'content-type': 'application/json'},
            );
          }
          // Third attempt: 200 OK success
          return http.Response(
            sampleGemini200Body,
            200,
            headers: {'content-type': 'application/json'},
          );
        });

        final service = GeminiService(
          client: mockClient,
          maxRetries: 3,
          delayFn: (d) async => delays.add(d),
        );

        final result = await service.analyzeResume('Senior Dart Developer');

        expect(callCount, 3);
        expect(delays.length, 2);
        expect(result.score, 85);
      },
    );

    test(
      'retries on TimeoutException and succeeds when server answers on retry',
      () async {
        int callCount = 0;
        final delays = <Duration>[];

        final mockClient = MockClient((request) async {
          callCount++;
          if (callCount == 1) {
            throw TimeoutException('Simulated network timeout');
          }
          return http.Response(
            sampleGemini200Body,
            200,
            headers: {'content-type': 'application/json'},
          );
        });

        final service = GeminiService(
          client: mockClient,
          maxRetries: 3,
          delayFn: (d) async => delays.add(d),
        );

        final result = await service.analyzeResume('Mobile App Developer');

        expect(callCount, 2);
        expect(delays.length, 1);
        expect(result.score, 85);
      },
    );

    test(
      'does NOT retry on permanent 400 API_KEY_INVALID error (fails immediately in 1 call)',
      () async {
        int callCount = 0;
        final delays = <Duration>[];

        final mockClient = MockClient((request) async {
          callCount++;
          return http.Response(
            jsonEncode({
              'error': {
                'code': 400,
                'message': 'API key not valid. Please pass a valid API key.',
                'status': 'INVALID_ARGUMENT',
                'details': [
                  {
                    '@type': 'type.googleapis.com/google.rpc.ErrorInfo',
                    'reason': 'API_KEY_INVALID',
                  },
                ],
              },
            }),
            400,
            headers: {'content-type': 'application/json'},
          );
        });

        final service = GeminiService(
          client: mockClient,
          maxRetries: 3,
          delayFn: (d) async => delays.add(d),
        );

        await expectLater(
          () => service.analyzeResume('Candidate Resume'),
          throwsA(
            isA<GeminiApiException>()
                .having((e) => e.statusCode, 'statusCode', 400)
                .having((e) => e.isTransient, 'isTransient', isFalse)
                .having(
                  (e) => e.message,
                  'message',
                  contains('API key is invalid'),
                ),
          ),
        );

        // Verification: Only 1 attempt was made; no wasteful retries
        expect(callCount, 1);
        expect(delays, isEmpty);
      },
    );

    test(
      'does NOT retry on 403 Forbidden / Permission Denied (fails immediately in 1 call)',
      () async {
        int callCount = 0;
        final delays = <Duration>[];

        final mockClient = MockClient((request) async {
          callCount++;
          return http.Response(
            jsonEncode({
              'error': {
                'code': 403,
                'message': 'The caller does not have permission',
                'status': 'PERMISSION_DENIED',
              },
            }),
            403,
            headers: {'content-type': 'application/json'},
          );
        });

        final service = GeminiService(
          client: mockClient,
          maxRetries: 3,
          delayFn: (d) async => delays.add(d),
        );

        await expectLater(
          () => service.analyzeResume('Candidate Resume'),
          throwsA(
            isA<GeminiApiException>()
                .having((e) => e.statusCode, 'statusCode', 403)
                .having((e) => e.isTransient, 'isTransient', isFalse),
          ),
        );

        expect(callCount, 1);
        expect(delays, isEmpty);
      },
    );

    test(
      'exhausts all retries when 503 high demand persists and throws descriptive GeminiApiException',
      () async {
        int callCount = 0;
        final delays = <Duration>[];
        final statusUpdates = <String>[];

        final mockClient = MockClient((request) async {
          callCount++;
          return http.Response(
            jsonEncode({
              'error': {
                'code': 503,
                'message':
                    'This model is currently experiencing high demand. Spikes in demand are usually temporary. Please try again later.',
                'status': 'UNAVAILABLE',
              },
            }),
            503,
            headers: {'content-type': 'application/json'},
          );
        });

        final service = GeminiService(
          client: mockClient,
          maxRetries: 3,
          delayFn: (d) async => delays.add(d),
        );

        await expectLater(
          () => service.analyzeResume(
            'Candidate Resume',
            onStatusUpdate: (msg) => statusUpdates.add(msg),
          ),
          throwsA(
            isA<GeminiApiException>()
                .having((e) => e.statusCode, 'statusCode', 503)
                .having((e) => e.isTransient, 'isTransient', isTrue)
                .having(
                  (e) => e.message,
                  'message',
                  contains('high demand after 3 retry attempts'),
                ),
          ),
        );

        // 1 initial attempt + 3 retries = 4 total attempts
        expect(callCount, 4);
        expect(delays.length, 3);
        expect(statusUpdates.length, 3);
      },
    );

    test('supports dynamic model name configuration via GeminiConfig', () {
      expect(GeminiConfig.modelName, 'gemini-3.8-flash');

      GeminiConfig.setRuntimeModel('gemini-3.6-flash');
      expect(GeminiConfig.modelName, 'gemini-3.6-flash');

      GeminiConfig.clearRuntimeModel();
      expect(GeminiConfig.modelName, 'gemini-3.8-flash');
    });
  });
}

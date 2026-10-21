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

  group('GeminiService Quota, Fallback & Retry Tests', () {
    test(
      'retries on transient 503 high demand error and succeeds when next attempt is 200 OK',
      () async {
        int callCount = 0;
        final delays = <Duration>[];

        final mockClient = MockClient((request) async {
          callCount++;
          if (callCount == 1) {
            return http.Response(
              jsonEncode({
                'error': {
                  'code': 503,
                  'message':
                      'This model is currently experiencing high demand. Spikes in demand are usually temporary.',
                  'status': 'UNAVAILABLE',
                },
              }),
              503,
              headers: {'content-type': 'application/json'},
            );
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
          enableModelFallback: false,
          delayFn: (d) async => delays.add(d),
        );

        final result = await service.analyzeResume('Experienced Flutter Developer');

        expect(callCount, 2);
        expect(delays.length, 1);
        expect(result.score, 85);
      },
    );

    test(
      'respects server Retry-After / RetryInfo delay for transient 429 rate limit',
      () async {
        int callCount = 0;
        final delays = <Duration>[];

        final mockClient = MockClient((request) async {
          callCount++;
          if (callCount == 1) {
            // First attempt: 429 with 4s RetryInfo
            return http.Response(
              jsonEncode({
                'error': {
                  'code': 429,
                  'message': 'Rate limit exceeded.',
                  'status': 'RESOURCE_EXHAUSTED',
                  'details': [
                    {
                      '@type': 'type.googleapis.com/google.rpc.RetryInfo',
                      'retryDelay': '4s',
                    },
                  ],
                },
              }),
              429,
              headers: {'content-type': 'application/json', 'retry-after': '4'},
            );
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
          enableModelFallback: false,
          delayFn: (d) async => delays.add(d),
        );

        final result = await service.analyzeResume('Senior Dart Developer');

        expect(callCount, 2);
        expect(delays.length, 1);
        expect(delays.first.inSeconds, 4);
        expect(result.score, 85);
      },
    );

    test(
      'detects hard quota exhaustion and attempts fallback model successfully',
      () async {
        final modelsRequested = <String>[];

        final mockClient = MockClient((request) async {
          final uri = request.url.toString();
          if (uri.contains('gemini-2.0-flash')) {
            modelsRequested.add('gemini-2.0-flash');
            // Primary model: daily quota exhausted (hard limit)
            return http.Response(
              jsonEncode({
                'error': {
                  'code': 429,
                  'message': 'Quota exceeded for quota metric GenerateContentRequestsPerDay',
                  'status': 'RESOURCE_EXHAUSTED',
                  'details': [
                    {
                      '@type': 'type.googleapis.com/google.rpc.QuotaFailure',
                      'violations': [
                        {
                          'quotaMetric': 'GenerateContentRequestsPerDayPerProject',
                          'description': 'Daily request quota exceeded',
                        },
                      ],
                    },
                  ],
                },
              }),
              429,
              headers: {'content-type': 'application/json'},
            );
          } else if (uri.contains('gemini-1.5-flash')) {
            modelsRequested.add('gemini-1.5-flash');
            // Fallback model: succeeds with 200 OK
            return http.Response(
              sampleGemini200Body,
              200,
              headers: {'content-type': 'application/json'},
            );
          }
          return http.Response('Not Found', 404);
        });

        final service = GeminiService(
          client: mockClient,
          maxRetries: 3,
          enableModelFallback: true,
          fallbackModels: const ['gemini-1.5-flash'],
        );

        final result = await service.analyzeResume('Candidate with active fallback');

        expect(modelsRequested, contains('gemini-2.0-flash'));
        expect(modelsRequested, contains('gemini-1.5-flash'));
        expect(result.score, 85);
      },
    );

    test(
      'does NOT loop through futile retries when hard daily quota is exhausted without fallback',
      () async {
        int callCount = 0;
        final delays = <Duration>[];

        final mockClient = MockClient((request) async {
          callCount++;
          return http.Response(
            jsonEncode({
              'error': {
                'code': 429,
                'message': 'Daily quota exhausted for this model.',
                'status': 'RESOURCE_EXHAUSTED',
                'details': [
                  {
                    '@type': 'type.googleapis.com/google.rpc.QuotaFailure',
                    'violations': [
                      {
                        'quotaMetric': 'PerDay',
                        'description': 'Daily request quota exceeded',
                      },
                    ],
                  },
                ],
              },
            }),
            429,
            headers: {'content-type': 'application/json'},
          );
        });

        final service = GeminiService(
          client: mockClient,
          maxRetries: 3,
          enableModelFallback: false,
          delayFn: (d) async => delays.add(d),
        );

        await expectLater(
          () => service.analyzeResume('Candidate Resume'),
          throwsA(
            isA<GeminiApiException>()
                .having((e) => e.statusCode, 'statusCode', 429)
                .having((e) => e.isQuotaExhausted, 'isQuotaExhausted', isTrue)
                .having((e) => e.message, 'message', contains('Daily request quota exceeded')),
          ),
        );

        // Crucial test: Only 1 attempt made because it detected hard quota exhaustion
        expect(callCount, 1);
        expect(delays, isEmpty);
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
          enableModelFallback: false,
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
          enableModelFallback: true,
          delayFn: (d) async => delays.add(d),
        );

        await expectLater(
          () => service.analyzeResume('Candidate Resume'),
          throwsA(
            isA<GeminiApiException>()
                .having((e) => e.statusCode, 'statusCode', 400)
                .having((e) => e.isTransient, 'isTransient', isFalse)
                .having((e) => e.message, 'message', contains('API key is invalid')),
          ),
        );

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
          enableModelFallback: true,
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

    test('handles malformed JSON from model gracefully without crashing', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'candidates': [
              {
                'content': {
                  'parts': [
                    {'text': 'This is plain text, not JSON!'},
                  ],
                },
              },
            ],
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final service = GeminiService(
        client: mockClient,
        maxRetries: 1,
        enableModelFallback: false,
      );

      await expectLater(
        () => service.analyzeResume('Candidate Resume'),
        throwsA(
          isA<GeminiApiException>().having(
            (e) => e.message,
            'message',
            contains('Failed to parse analysis results from Gemini'),
          ),
        ),
      );
    });

    test('supports dynamic model name configuration via GeminiConfig', () {
      expect(GeminiConfig.modelName, 'gemini-2.0-flash');

      GeminiConfig.setRuntimeModel('gemini-1.5-flash');
      expect(GeminiConfig.modelName, 'gemini-1.5-flash');

      GeminiConfig.clearRuntimeModel();
      expect(GeminiConfig.modelName, 'gemini-2.0-flash');
    });
  });
}

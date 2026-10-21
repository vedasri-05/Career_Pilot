import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;

import '../config/gemini_config.dart';
import '../models/resume_analysis_model.dart';

class GeminiApiException implements Exception {
  final String message;
  final int? statusCode;
  final bool isTransient;
  final bool isQuotaExhausted;
  final String? modelAttempted;

  const GeminiApiException(
    this.message, {
    this.statusCode,
    this.isTransient = false,
    this.isQuotaExhausted = false,
    this.modelAttempted,
  });

  @override
  String toString() => message;
}

class GeminiService {
  final http.Client? _customClient;
  final int maxRetries;
  final Duration initialDelay;
  final Duration maxDelay;
  final bool enableModelFallback;
  final List<String> fallbackModels;
  final Future<void> Function(Duration)? delayFn;
  final Random _random;

  GeminiService({
    http.Client? client,
    this.maxRetries = 3,
    this.initialDelay = const Duration(milliseconds: 1500),
    this.maxDelay = const Duration(seconds: 10),
    this.enableModelFallback = true,
    this.fallbackModels = const ['gemini-1.5-flash', 'gemini-2.5-flash'],
    this.delayFn,
    Random? random,
  })  : _customClient = client,
        _random = random ?? Random();

  /// Calculates bounded exponential backoff delay with jitter.
  Duration calculateBackoffWithJitter(int retryIndex) {
    final exponentialFactor = pow(2, retryIndex).toInt();
    final baseMs = initialDelay.inMilliseconds * exponentialFactor;
    final cappedMs = min(baseMs, maxDelay.inMilliseconds);
    // Decorrelated uniform jitter in range [0.8, 1.2]
    final jitterMultiplier = 0.8 + (_random.nextDouble() * 0.4);
    final finalMs = (cappedMs * jitterMultiplier).round();
    return Duration(
      milliseconds: max(initialDelay.inMilliseconds ~/ 2, finalMs),
    );
  }

  Future<void> _sleep(Duration duration) async {
    if (delayFn != null) {
      await delayFn!(duration);
    } else {
      await Future<void>.delayed(duration);
    }
  }

  /// Parses server-recommended retry delay from Retry-After header or RetryInfo details.
  Duration? _extractServerRetryDelay(
    http.Response response,
    Map<String, dynamic>? errorJson,
  ) {
    // 1. Check HTTP 'Retry-After' header (seconds)
    final retryAfterHeader = response.headers['retry-after'];
    if (retryAfterHeader != null) {
      final seconds = int.tryParse(retryAfterHeader.trim());
      if (seconds != null && seconds > 0) {
        return Duration(seconds: seconds);
      }
    }

    // 2. Check google.rpc.RetryInfo in error.details
    if (errorJson != null && errorJson['error'] is Map) {
      final details = errorJson['error']['details'] as List?;
      if (details != null) {
        for (final detail in details) {
          if (detail is Map &&
              detail['@type'] == 'type.googleapis.com/google.rpc.RetryInfo') {
            final delayStr = detail['retryDelay'] as String?;
            if (delayStr != null) {
              final clean = delayStr.replaceAll('s', '').trim();
              final sec = double.tryParse(clean);
              if (sec != null && sec > 0) {
                return Duration(milliseconds: (sec * 1000).round());
              }
            }
          }
        }
      }
    }

    return null;
  }

  /// Inspects error details to determine if quota is exhausted (daily/project limits).
  bool _detectHardQuotaExhaustion(
    int statusCode,
    String errorMessage,
    String errorStatus,
    Map<String, dynamic>? errorJson,
    Duration? serverRetryDelay,
  ) {
    if (statusCode != 429 && errorStatus != 'RESOURCE_EXHAUSTED') {
      return false;
    }

    final lowerMsg = errorMessage.toLowerCase();

    // If server asks to wait longer than 30 seconds, it is not a 2-second rate burst
    if (serverRetryDelay != null && serverRetryDelay.inSeconds > 30) {
      return true;
    }

    // Check message keywords
    if (lowerMsg.contains('per day') ||
        lowerMsg.contains('perday') ||
        lowerMsg.contains('daily') ||
        lowerMsg.contains('exhausted your capacity') ||
        lowerMsg.contains('limit: 0') ||
        lowerMsg.contains('quota exceeded for metric')) {
      return true;
    }

    // Check violations in error.details
    if (errorJson != null && errorJson['error'] is Map) {
      final details = errorJson['error']['details'] as List?;
      if (details != null) {
        for (final detail in details) {
          if (detail is Map && detail['violations'] is List) {
            for (final v in detail['violations']) {
              if (v is Map) {
                final metric = (v['quotaMetric'] as String? ?? '').toLowerCase();
                final desc = (v['description'] as String? ?? '').toLowerCase();
                if (metric.contains('day') ||
                    desc.contains('daily') ||
                    desc.contains('per day') ||
                    desc.contains('exhausted')) {
                  return true;
                }
              }
            }
          }
        }
      }
    }

    return false;
  }

  /// Extracts human-readable quota violation summary if present.
  String _extractViolationSummary(Map<String, dynamic>? errorJson) {
    if (errorJson == null || errorJson['error'] is! Map) return '';
    final details = errorJson['error']['details'] as List?;
    if (details == null) return '';

    for (final detail in details) {
      if (detail is Map && detail['violations'] is List) {
        final descriptions = (detail['violations'] as List)
            .map((v) => v is Map
                ? (v['description'] as String? ?? v['quotaMetric'] as String? ?? '')
                : '')
            .where((s) => s.isNotEmpty)
            .join(', ');
        if (descriptions.isNotEmpty) {
          return ' ($descriptions)';
        }
      }
    }
    return '';
  }

  /// Analyzes the extracted resume text using the Gemini API.
  Future<ResumeAnalysisModel> analyzeResume(
    String resumeText, {
    void Function(String message)? onStatusUpdate,
  }) async {
    final apiKey = GeminiConfig.apiKey;
    if (apiKey.isEmpty) {
      throw const GeminiApiException(
        'Gemini API key is not configured. Please launch the app with --dart-define=GEMINI_API_KEY=your_key',
        isTransient: false,
      );
    }

    if (resumeText.trim().isEmpty) {
      throw const GeminiApiException(
        'The resume text is empty. Please provide a document with readable content.',
        isTransient: false,
      );
    }

    final prompt =
        '''
You are an expert career consultant, senior technical recruiter, and ATS (Applicant Tracking System) specialist.
Analyze the following resume thoroughly and provide a structured assessment in valid JSON format.

Resume text:
"""
$resumeText
"""

You MUST respond strictly with a valid JSON object matching the following structure without any extra commentary:
{
  "score": <integer between 0 and 100 representing overall resume quality, impact, and completeness>,
  "strengths": [
    "<detailed bullet point highlighting a key strength in experience, structure, or presentation>",
    ...
  ],
  "weaknesses": [
    "<detailed bullet point highlighting an area needing attention, missing impact metrics, or weak wording>",
    ...
  ],
  "demonstratedSkills": [
    "<skill clearly demonstrated with context or evidence in the resume>",
    ...
  ],
  "missingSkills": [
    "<in-demand industry skills that would strengthen this candidate's profile based on their field>",
    ...
  ],
  "atsFeedback": "<comprehensive paragraph or assessment explaining ATS parsability, section clarity, standard headings, bullet formatting, and keyword density>",
  "improvementSuggestions": [
    "<specific, actionable recommendation to improve this resume's impact, formatting, or clarity>",
    ...
  ]
}
''';

    final requestBody = jsonEncode({
      'contents': [
        {
          'parts': [
            {'text': prompt},
          ],
        },
      ],
      'generationConfig': {
        'responseMimeType': 'application/json',
        'temperature': 0.2,
      },
    });

    final client = _customClient ?? http.Client();

    // Prepare list of models to try (primary model followed by fallbacks if enabled)
    final modelsToTry = <String>[GeminiConfig.modelName];
    if (enableModelFallback) {
      for (final fb in fallbackModels) {
        if (!modelsToTry.contains(fb)) {
          modelsToTry.add(fb);
        }
      }
    }

    try {
      for (int mIndex = 0; mIndex < modelsToTry.length; mIndex++) {
        final currentModel = modelsToTry[mIndex];
        final isLastModel = mIndex == modelsToTry.length - 1;

        final endpoint = Uri.parse(
          'https://generativelanguage.googleapis.com/v1beta/models/$currentModel:generateContent?key=$apiKey',
        );

        int attempt = 0;
        while (true) {
          attempt++;
          try {
            final response = await client
                .post(
                  endpoint,
                  headers: {
                    'Content-Type': 'application/json',
                    'x-goog-api-key': apiKey,
                  },
                  body: requestBody,
                )
                .timeout(const Duration(seconds: 45));

            if (response.statusCode != 200) {
              String errorMessage =
                  'Gemini API returned status ${response.statusCode}';
              String errorStatus = '';
              Map<String, dynamic>? errorJson;

              try {
                errorJson = jsonDecode(response.body) as Map<String, dynamic>?;
                if (errorJson != null && errorJson['error'] is Map) {
                  final err = errorJson['error'] as Map;
                  if (err['message'] != null) {
                    errorMessage = err['message'].toString();
                  }
                  if (err['status'] != null) {
                    errorStatus = err['status'].toString();
                  }
                  final details = err['details'] as List?;
                  if (details != null) {
                    for (final detail in details) {
                      if (detail is Map &&
                          detail['reason'] == 'API_KEY_INVALID') {
                        errorMessage = 'API_KEY_INVALID: $errorMessage';
                      }
                    }
                  }
                }
              } catch (_) {}

              // Non-retryable permanent client errors
              if (response.statusCode == 400) {
                if (errorMessage.contains('API_KEY_INVALID') ||
                    errorMessage.toLowerCase().contains('api key not valid')) {
                  throw const GeminiApiException(
                    'The provided Gemini API key is invalid. Please verify your API key.',
                    statusCode: 400,
                    isTransient: false,
                  );
                }
                throw GeminiApiException(
                  errorMessage,
                  statusCode: 400,
                  isTransient: false,
                  modelAttempted: currentModel,
                );
              } else if (response.statusCode == 403) {
                throw GeminiApiException(
                  'Access forbidden ($errorMessage). Ensure your API key has Generative Language API enabled in Google Cloud/Google AI Studio.',
                  statusCode: 403,
                  isTransient: false,
                  modelAttempted: currentModel,
                );
              }

              final serverRetryDelay =
                  _extractServerRetryDelay(response, errorJson);
              final isHardQuota = _detectHardQuotaExhaustion(
                response.statusCode,
                errorMessage,
                errorStatus,
                errorJson,
                serverRetryDelay,
              );
              final violationSummary = _extractViolationSummary(errorJson);

              // If hard quota is exhausted on this model, do not loop retries
              if (isHardQuota) {
                if (!isLastModel) {
                  final nextModel = modelsToTry[mIndex + 1];
                  onStatusUpdate?.call(
                    'Quota reached for $currentModel. Switching to fallback model ($nextModel)...',
                  );
                  break; // Break attempt loop to proceed to next model in fallback list
                }

                throw GeminiApiException(
                  'Gemini API quota exhausted for model $currentModel$violationSummary ($errorMessage). '
                  'Daily quotas reset at midnight Pacific Time. Please check your project quota at '
                  'https://aistudio.google.com or switch models via --dart-define=GEMINI_MODEL=gemini-1.5-flash.',
                  statusCode: 429,
                  isTransient: false,
                  isQuotaExhausted: true,
                  modelAttempted: currentModel,
                );
              }

              // Check if transient error eligible for retry
              final isTransient = response.statusCode == 503 ||
                  response.statusCode == 429 ||
                  response.statusCode == 500 ||
                  response.statusCode == 502 ||
                  response.statusCode == 504 ||
                  errorStatus == 'UNAVAILABLE' ||
                  errorStatus == 'RESOURCE_EXHAUSTED' ||
                  errorMessage.toLowerCase().contains('high demand') ||
                  errorMessage.toLowerCase().contains('temporarily overloaded');

              if (isTransient && attempt <= maxRetries) {
                // Respect server Retry-After / RetryInfo if specified, otherwise use jittered backoff
                final delay = (serverRetryDelay != null &&
                        serverRetryDelay.inSeconds <= 15)
                    ? serverRetryDelay
                    : calculateBackoffWithJitter(attempt - 1);

                final statusNotice = response.statusCode == 429
                    ? 'Rate limit reached on $currentModel. Retrying in ${(delay.inMilliseconds / 1000).toStringAsFixed(1)}s (attempt $attempt of $maxRetries)...'
                    : 'Gemini service is experiencing high demand. Retrying in ${(delay.inMilliseconds / 1000).toStringAsFixed(1)}s (attempt $attempt of $maxRetries)...';
                onStatusUpdate?.call(statusNotice);
                await _sleep(delay);
                continue;
              }

              // If retries exhausted and fallback models remain, try next model
              if (!isLastModel && isTransient) {
                final nextModel = modelsToTry[mIndex + 1];
                onStatusUpdate?.call(
                  '$currentModel unavailable after $maxRetries retries. Trying fallback model $nextModel...',
                );
                break;
              }

              // All retries and models exhausted
              if (response.statusCode == 503 ||
                  errorMessage.contains('high demand') ||
                  errorStatus == 'UNAVAILABLE') {
                throw GeminiApiException(
                  'Gemini model ($currentModel) is currently experiencing high demand after $maxRetries retry attempts. '
                  'Spikes in demand are temporary. Please try again in a few moments or switch to gemini-1.5-flash.',
                  statusCode: 503,
                  isTransient: true,
                  modelAttempted: currentModel,
                );
              } else if (response.statusCode == 429 ||
                  errorStatus == 'RESOURCE_EXHAUSTED') {
                throw GeminiApiException(
                  'Rate limit or quota exceeded for model $currentModel after $maxRetries retry attempts$violationSummary. '
                  'Please check your Google AI Studio project quota or wait a few moments before trying again.',
                  statusCode: 429,
                  isTransient: true,
                  isQuotaExhausted: true,
                  modelAttempted: currentModel,
                );
              }

              throw GeminiApiException(
                errorMessage,
                statusCode: response.statusCode,
                isTransient: isTransient,
                modelAttempted: currentModel,
              );
            }

            final responseData = jsonDecode(response.body);
            final candidates = responseData['candidates'] as List?;
            if (candidates == null || candidates.isEmpty) {
              throw const GeminiApiException(
                'No analysis generated by Gemini. Please try again.',
              );
            }

            final candidate = candidates.first;
            final content = candidate['content'];
            final parts = content?['parts'] as List?;
            if (parts == null || parts.isEmpty) {
              throw const GeminiApiException(
                'Gemini returned an empty response. Please try again.',
              );
            }

            String rawText = parts.first['text'] as String? ?? '';
            rawText = rawText.trim();

            // Clean markdown code blocks if present
            if (rawText.startsWith('```json')) {
              rawText = rawText.substring(7);
            } else if (rawText.startsWith('```')) {
              rawText = rawText.substring(3);
            }
            if (rawText.endsWith('```')) {
              rawText = rawText.substring(0, rawText.length - 3);
            }
            rawText = rawText.trim();

            final parsedJson = jsonDecode(rawText) as Map<String, dynamic>;
            return ResumeAnalysisModel.fromJson(parsedJson);
          } on TimeoutException {
            if (attempt <= maxRetries) {
              final delay = calculateBackoffWithJitter(attempt - 1);
              final statusNotice =
                  'Connection timed out. Retrying in ${(delay.inMilliseconds / 1000).toStringAsFixed(1)}s (attempt $attempt of $maxRetries)...';
              onStatusUpdate?.call(statusNotice);
              await _sleep(delay);
              continue;
            }
            if (!isLastModel) {
              final nextModel = modelsToTry[mIndex + 1];
              onStatusUpdate?.call(
                'Connection timed out on $currentModel. Trying fallback model $nextModel...',
              );
              break;
            }
            throw GeminiApiException(
              'Gemini analysis request timed out after $maxRetries retry attempts. Please check your internet connection and try again.',
              isTransient: true,
              modelAttempted: currentModel,
            );
          } on GeminiApiException {
            rethrow;
          } on FormatException catch (e) {
            throw GeminiApiException(
              'Failed to parse analysis results from Gemini: ${e.message}',
              modelAttempted: currentModel,
            );
          } catch (e) {
            if (attempt <= maxRetries) {
              final delay = calculateBackoffWithJitter(attempt - 1);
              final statusNotice =
                  'Network connection glitch. Retrying in ${(delay.inMilliseconds / 1000).toStringAsFixed(1)}s (attempt $attempt of $maxRetries)...';
              onStatusUpdate?.call(statusNotice);
              await _sleep(delay);
              continue;
            }
            if (!isLastModel) {
              break;
            }
            throw GeminiApiException(
              'Network error while connecting to Gemini: $e',
              modelAttempted: currentModel,
            );
          }
        }
      }

      throw const GeminiApiException(
        'Unable to analyze resume after attempting available models. Please check your network and Google AI Studio quota.',
      );
    } finally {
      if (_customClient == null) {
        client.close();
      }
    }
  }
}

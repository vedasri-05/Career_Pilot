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

  const GeminiApiException(
    this.message, {
    this.statusCode,
    this.isTransient = false,
  });

  @override
  String toString() => message;
}

class GeminiService {
  final http.Client? _customClient;
  final int maxRetries;
  final Duration initialDelay;
  final Duration maxDelay;
  final Future<void> Function(Duration)? delayFn;
  final Random _random;

  GeminiService({
    http.Client? client,
    this.maxRetries = 3,
    this.initialDelay = const Duration(milliseconds: 1500),
    this.maxDelay = const Duration(seconds: 10),
    this.delayFn,
    Random? random,
  }) : _customClient = client,
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

  bool _isTransientStatusCode(int statusCode) {
    return statusCode == 503 ||
        statusCode == 429 ||
        statusCode == 500 ||
        statusCode == 502 ||
        statusCode == 504;
  }

  bool _isTransientMessage(String message, String errorStatus) {
    if (errorStatus == 'UNAVAILABLE' || errorStatus == 'RESOURCE_EXHAUSTED') {
      return true;
    }
    final lower = message.toLowerCase();
    return lower.contains('high demand') ||
        lower.contains('temporarily overloaded') ||
        lower.contains('resource exhausted') ||
        lower.contains('spikes in demand') ||
        lower.contains('try again later');
  }

  /// Analyzes the extracted resume text using the Gemini API with bounded exponential backoff.
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

    final endpoint = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/${GeminiConfig.modelName}:generateContent?key=$apiKey',
    );

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

    try {
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
            try {
              final errorJson = jsonDecode(response.body);
              if (errorJson['error'] != null) {
                if (errorJson['error']['message'] != null) {
                  errorMessage = errorJson['error']['message'];
                }
                if (errorJson['error']['status'] != null) {
                  errorStatus = errorJson['error']['status'];
                }
                final details = errorJson['error']['details'] as List?;
                if (details != null && details.isNotEmpty) {
                  for (final detail in details) {
                    if (detail is Map &&
                        detail['reason'] == 'API_KEY_INVALID') {
                      errorMessage = 'API_KEY_INVALID: $errorMessage';
                    }
                  }
                }
              }
            } catch (_) {
              // Keep generic message
            }

            // Non-retryable client errors (invalid key, forbidden, bad request)
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
              );
            } else if (response.statusCode == 403) {
              throw GeminiApiException(
                'Access forbidden ($errorMessage). Ensure your API key has Generative Language API enabled.',
                statusCode: 403,
                isTransient: false,
              );
            }

            // Check if transient error eligible for retry
            final isTransient =
                _isTransientStatusCode(response.statusCode) ||
                _isTransientMessage(errorMessage, errorStatus);

            if (isTransient && attempt <= maxRetries) {
              final delay = calculateBackoffWithJitter(attempt - 1);
              final statusNotice =
                  'Gemini model is currently experiencing high demand. Retrying in ${(delay.inMilliseconds / 1000).toStringAsFixed(1)}s (attempt $attempt of $maxRetries)...';
              onStatusUpdate?.call(statusNotice);
              await _sleep(delay);
              continue;
            }

            // Exhausted retries or non-retryable server error
            if (response.statusCode == 503 ||
                errorMessage.contains('high demand') ||
                errorStatus == 'UNAVAILABLE') {
              throw GeminiApiException(
                'Gemini model is currently experiencing high demand after $maxRetries retry attempts. Spikes in demand are usually temporary. Please try again in a few moments.',
                statusCode: 503,
                isTransient: true,
              );
            } else if (response.statusCode == 429 ||
                errorStatus == 'RESOURCE_EXHAUSTED') {
              throw GeminiApiException(
                'Rate limit or quota exceeded after $maxRetries retry attempts. Please wait a moment and try again.',
                statusCode: 429,
                isTransient: true,
              );
            }

            throw GeminiApiException(
              errorMessage,
              statusCode: response.statusCode,
              isTransient: isTransient,
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
          throw GeminiApiException(
            'Gemini analysis request timed out after $maxRetries retry attempts. Please check your internet connection and try again.',
            isTransient: true,
          );
        } on GeminiApiException {
          rethrow;
        } on FormatException catch (e) {
          throw GeminiApiException(
            'Failed to parse analysis results from Gemini: ${e.message}',
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
          throw GeminiApiException(
            'Network error while connecting to Gemini: $e',
          );
        }
      }
    } finally {
      if (_customClient == null) {
        client.close();
      }
    }
  }
}

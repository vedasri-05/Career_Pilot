import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:career_pilot/config/gemini_config.dart';
import 'package:career_pilot/models/resume_analysis_model.dart';
import 'package:career_pilot/services/gemini_service.dart';
import 'package:career_pilot/services/resume_extractor_service.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

void main() {
  group('ResumeAnalysisModel Tests', () {
    test('successfully parses valid JSON from Gemini', () {
      final json = {
        'score': 88,
        'strengths': [
          'Strong Flutter experience with state management',
          'Clear chronological project descriptions',
        ],
        'weaknesses': ['Lacks quantifiable metrics for business impact'],
        'demonstratedSkills': ['Flutter', 'Dart', 'Firebase'],
        'missingSkills': ['CI/CD', 'Automated Testing', 'GraphQL'],
        'atsFeedback':
            'Well-formatted resume with clear headings and standard bullet points.',
        'improvementSuggestions': [
          'Add percentage improvements to project outcomes.',
          'Include a dedicated certifications section.',
        ],
      };

      final model = ResumeAnalysisModel.fromJson(json);

      expect(model.score, 88);
      expect(model.strengths.length, 2);
      expect(model.weaknesses.length, 1);
      expect(model.demonstratedSkills, contains('Flutter'));
      expect(model.missingSkills, contains('CI/CD'));
      expect(model.atsFeedback, contains('Well-formatted'));
      expect(model.improvementSuggestions.length, 2);
    });

    test('safely clamps score and handles null or empty fields', () {
      final json = {
        'score': 150, // Should clamp to 100
        'strengths': null,
        'weaknesses': ['  '],
        'demonstratedSkills': null,
        'missingSkills': null,
        'atsFeedback': null,
        'improvementSuggestions': null,
      };

      final model = ResumeAnalysisModel.fromJson(json);

      expect(model.score, 100);
      expect(model.strengths, isEmpty);
      expect(model.weaknesses, isEmpty);
      expect(model.demonstratedSkills, isEmpty);
      expect(model.missingSkills, isEmpty);
      expect(model.atsFeedback, 'No specific ATS feedback provided.');
      expect(model.improvementSuggestions, isEmpty);
    });
  });

  group('GeminiConfig & GeminiService Tests', () {
    test('manages runtime API key correctly for testing', () {
      GeminiConfig.clearRuntimeApiKey();

      GeminiConfig.setRuntimeApiKey('test_gemini_key_123');
      expect(GeminiConfig.apiKey, 'test_gemini_key_123');
      expect(GeminiConfig.hasApiKey, isTrue);

      GeminiConfig.clearRuntimeApiKey();
    });

    test('preserves the configured Gemini model name', () {
      expect(GeminiConfig.modelName, 'gemini-2.0-flash');
    });

    test(
      'throws GeminiApiException with configuration message when API key is missing',
      () async {
        GeminiConfig.clearRuntimeApiKey();
        final service = GeminiService();

        expect(
          () => service.analyzeResume('Some test resume content'),
          throwsA(
            isA<GeminiApiException>().having(
              (e) => e.message,
              'message',
              contains('--dart-define=GEMINI_API_KEY='),
            ),
          ),
        );
      },
    );
  });

  group('ResumeExtractorService Size & Format Validation', () {
    const int maxBytes = ResumeExtractorService.maxFileSizeBytes; // 5 MB

    test('accepts valid PDF resume below 5 MB limit and extracts text', () {
      final document = PdfDocument();
      final page = document.pages.add();
      final font = PdfStandardFont(PdfFontFamily.helvetica, 12);
      const testContent =
          'Jane Smith Senior Mobile Engineer with 6 years experience building production Flutter applications.';
      page.graphics.drawString(
        testContent,
        font,
        bounds: const Rect.fromLTWH(0, 0, 500, 50),
      );
      final pdfBytes = Uint8List.fromList(document.saveSync());
      document.dispose();

      expect(pdfBytes.length, lessThan(maxBytes));

      final extracted = ResumeExtractorService.extractTextFromBytes(
        pdfBytes,
        'pdf',
      );

      expect(extracted, contains('Jane Smith Senior Mobile Engineer'));
      expect(extracted, contains('Flutter'));
    });

    test(
      'rejects oversized resume (> 5 MB) for PDF files before extraction',
      () {
        // 5 MB + 1 byte
        final oversizedPdfBytes = Uint8List(maxBytes + 1);

        expect(
          () => ResumeExtractorService.extractTextFromBytes(
            oversizedPdfBytes,
            'pdf',
          ),
          throwsA(
            isA<ResumeExtractorException>()
                .having((e) => e.isFileTooLarge, 'isFileTooLarge', isTrue)
                .having(
                  (e) => e.message,
                  'message',
                  equals(ResumeExtractorService.maxFileSizeErrorMessage),
                ),
          ),
        );
      },
    );

    test(
      'rejects oversized resume (> 5 MB) for DOCX files before extraction',
      () {
        // 5 MB + 1024 bytes
        final oversizedDocxBytes = Uint8List(maxBytes + 1024);

        expect(
          () => ResumeExtractorService.extractTextFromBytes(
            oversizedDocxBytes,
            'docx',
          ),
          throwsA(
            isA<ResumeExtractorException>()
                .having((e) => e.isFileTooLarge, 'isFileTooLarge', isTrue)
                .having(
                  (e) => e.message,
                  'message',
                  equals(ResumeExtractorService.maxFileSizeErrorMessage),
                ),
          ),
        );
      },
    );

    test('does not throw isFileTooLarge on a file at exactly 5 MB limit', () {
      // Create a 5 MB buffer (5 * 1024 * 1024 bytes)
      final exactLimitBytes = Uint8List(maxBytes);

      // Testing that the file size check alone doesn't reject 5 MB
      // It will throw because bytes are zeroes (not valid PDF/DOCX), but NOT isFileTooLarge
      expect(
        () =>
            ResumeExtractorService.extractTextFromBytes(exactLimitBytes, 'pdf'),
        throwsA(
          isA<ResumeExtractorException>().having(
            (e) => e.isFileTooLarge,
            'isFileTooLarge',
            isFalse,
          ),
        ),
      );
    });

    test('throws honest ResumeExtractorException on legacy .doc files', () {
      final dummyBytes = Uint8List.fromList([1, 2, 3, 4]);

      expect(
        () => ResumeExtractorService.extractTextFromBytes(dummyBytes, 'doc'),
        throwsA(
          isA<ResumeExtractorException>().having(
            (e) => e.isUnsupportedFormat,
            'isUnsupportedFormat',
            isTrue,
          ),
        ),
      );
    });

    test(
      'throws honest ResumeExtractorException on unsupported file types',
      () {
        final dummyBytes = Uint8List.fromList([1, 2, 3, 4]);

        expect(
          () => ResumeExtractorService.extractTextFromBytes(dummyBytes, 'txt'),
          throwsA(
            isA<ResumeExtractorException>().having(
              (e) => e.isUnsupportedFormat,
              'isUnsupportedFormat',
              isTrue,
            ),
          ),
        );
      },
    );

    test('throws ResumeExtractorException on empty file bytes', () {
      final emptyBytes = Uint8List(0);

      expect(
        () => ResumeExtractorService.extractTextFromBytes(emptyBytes, 'pdf'),
        throwsA(isA<ResumeExtractorException>()),
      );
    });
  });
}

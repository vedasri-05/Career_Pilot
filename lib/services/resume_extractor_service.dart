import 'dart:convert';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:xml/xml.dart';

class ResumeExtractorException implements Exception {
  final String message;
  final bool isUnsupportedFormat;
  final bool isOcrNeeded;
  final bool isFileTooLarge;

  const ResumeExtractorException(
    this.message, {
    this.isUnsupportedFormat = false,
    this.isOcrNeeded = false,
    this.isFileTooLarge = false,
  });

  @override
  String toString() => message;
}

class ResumeExtractorService {
  /// Maximum permitted resume file size: 5 MB (5 * 1024 * 1024 bytes = 5,242,880 bytes)
  static const int maxFileSizeBytes = 5 * 1024 * 1024;

  /// Standard error message shown when a resume file exceeds the 5 MB limit.
  static const String maxFileSizeErrorMessage =
      'Resume file must be 5 MB or smaller. Please select another file.';

  /// Extracts plain text from the given [PlatformFile].
  /// Supports PDF and DOCX formats up to 5 MB in size.
  /// Validates file size before reading or extracting its contents.
  /// Throws [ResumeExtractorException] if format is unsupported, size > 5 MB, or text cannot be extracted.
  static Future<String> extractText(PlatformFile file) async {
    final extension = (file.extension ?? '').toLowerCase();

    // Check unsupported legacy .doc format early
    if (extension == 'doc') {
      throw const ResumeExtractorException(
        'Legacy binary .doc files are not supported for local text extraction. Please convert your file to .docx or text-based .pdf format.',
        isUnsupportedFormat: true,
      );
    }

    if (extension != 'pdf' && extension != 'docx') {
      throw ResumeExtractorException(
        'Unsupported file format: .${extension.isEmpty ? "unknown" : extension}. Only PDF and DOCX files are supported.',
        isUnsupportedFormat: true,
      );
    }

    // Validate file size immediately before reading full contents into memory
    int? fileSize = file.lengthSync();
    try {
      fileSize ??= await file.length();
    } catch (_) {
      // Platform-specific fallback
    }

    if (fileSize != null && fileSize > maxFileSizeBytes) {
      throw const ResumeExtractorException(
        maxFileSizeErrorMessage,
        isFileTooLarge: true,
      );
    }

    // Read bytes uniformly using file.readAsBytes()
    Uint8List bytes;
    try {
      bytes = await file.readAsBytes();
    } catch (e) {
      throw ResumeExtractorException('Failed to read file: $e');
    }

    // Safety guard after reading bytes
    if (bytes.length > maxFileSizeBytes) {
      throw const ResumeExtractorException(
        maxFileSizeErrorMessage,
        isFileTooLarge: true,
      );
    }

    return extractTextFromBytes(bytes, extension);
  }

  /// Extracts plain text directly from file bytes and extension.
  /// Enforces the 5 MB size restriction for all formats.
  static String extractTextFromBytes(Uint8List bytes, String extension) {
    final ext = extension.toLowerCase().replaceAll('.', '').trim();

    // Enforce 5 MB maximum file size limit
    if (bytes.length > maxFileSizeBytes) {
      throw const ResumeExtractorException(
        maxFileSizeErrorMessage,
        isFileTooLarge: true,
      );
    }

    if (ext == 'doc') {
      throw const ResumeExtractorException(
        'Legacy binary .doc files are not supported for local text extraction. Please convert your file to .docx or text-based .pdf format.',
        isUnsupportedFormat: true,
      );
    }

    if (ext != 'pdf' && ext != 'docx') {
      throw ResumeExtractorException(
        'Unsupported file format: .$ext. Only PDF and DOCX files are supported.',
        isUnsupportedFormat: true,
      );
    }

    if (bytes.isEmpty) {
      throw const ResumeExtractorException('The selected file is empty.');
    }

    if (ext == 'pdf') {
      return _extractFromPdf(bytes);
    } else {
      return _extractFromDocx(bytes);
    }
  }

  /// Extracts text from a PDF file using syncfusion_flutter_pdf.
  static String _extractFromPdf(Uint8List bytes) {
    PdfDocument? document;
    try {
      document = PdfDocument(inputBytes: bytes);
      final extractor = PdfTextExtractor(document);
      final text = extractor.extractText();

      // Check if text extraction yielded meaningful text
      final trimmed = text.trim();
      if (trimmed.length < 40) {
        throw const ResumeExtractorException(
          'No readable text could be extracted from this PDF. If this is a scanned or image-based document, OCR is currently unsupported. Please upload a standard text-based PDF or DOCX file.',
          isOcrNeeded: true,
        );
      }

      return trimmed;
    } on ResumeExtractorException {
      rethrow;
    } catch (e) {
      throw ResumeExtractorException('Failed to parse PDF document: $e');
    } finally {
      document?.dispose();
    }
  }

  /// Extracts text from a DOCX file by unzipping word/document.xml and reading `<w:t>` tags.
  static String _extractFromDocx(Uint8List bytes) {
    try {
      final archive = ZipDecoder().decodeBytes(bytes);
      final documentEntry = archive.findFile('word/document.xml');

      if (documentEntry == null) {
        throw const ResumeExtractorException(
          'Invalid DOCX file: missing document content.',
        );
      }

      final contentBytes = documentEntry.content as List<int>;
      final xmlString = utf8.decode(contentBytes, allowMalformed: true);
      final xmlDoc = XmlDocument.parse(xmlString);

      // In WordprocessingML, text content is held in <w:t> elements
      final textElements = xmlDoc.findAllElements('w:t');
      final buffer = StringBuffer();

      for (final element in textElements) {
        buffer.write(element.innerText);
        buffer.write(' ');
      }

      final result = buffer.toString().trim();
      if (result.length < 40) {
        throw const ResumeExtractorException(
          'No readable text found in the DOCX document. Please ensure the document contains resume text.',
        );
      }

      return result;
    } on ResumeExtractorException {
      rethrow;
    } catch (e) {
      throw ResumeExtractorException('Failed to parse DOCX document: $e');
    }
  }
}

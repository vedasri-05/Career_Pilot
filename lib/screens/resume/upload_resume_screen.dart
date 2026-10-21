import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../config/gemini_config.dart';
import '../../models/resume_analysis_model.dart';
import '../../services/gemini_service.dart';
import '../../services/resume_extractor_service.dart';
import '../../theme/app_theme.dart';
import 'resume_analysis_screen.dart';

class UploadResumeScreen extends StatefulWidget {
  const UploadResumeScreen({super.key});

  @override
  State<UploadResumeScreen> createState() => _UploadResumeScreenState();
}

class _UploadResumeScreenState extends State<UploadResumeScreen> {
  PlatformFile? selectedFile;
  int? selectedFileSize;
  bool isAnalyzing = false;
  String currentStatusMessage = '';
  String? errorMessage;

  // In-memory cache for the current session (never persisted to any database)
  ResumeAnalysisModel? lastAnalysis;
  String? lastAnalyzedFileName;

  final GeminiService _geminiService = GeminiService();

  // Select resume using the file picker and immediately validate file size (<= 5 MB)
  Future<void> selectResume() async {
    setState(() {
      errorMessage = null;
    });

    try {
      final file = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx'],
      );

      // Handle cancelled file selection gracefully
      if (file == null) {
        return;
      }

      final extension = (file.extension ?? '').toLowerCase();

      // Check legacy .doc format
      if (extension == 'doc') {
        setState(() {
          selectedFile = null;
          selectedFileSize = null;
          errorMessage =
              'Legacy binary .doc files are not supported. Please select a .pdf or .docx file.';
        });
        return;
      }

      // Check unsupported file format
      if (extension != 'pdf' && extension != 'docx') {
        setState(() {
          selectedFile = null;
          selectedFileSize = null;
          errorMessage =
              'Unsupported file format: .${extension.isEmpty ? "unknown" : extension}. Only PDF and DOCX files are supported.';
        });
        return;
      }

      // Immediately validate file size before reading or extracting contents
      int? size = file.lengthSync();
      try {
        size ??= await file.length();
      } catch (_) {
        // Fallback below
      }

      // Fallback byte check if length cannot be resolved synchronously
      if (size == null) {
        try {
          final bytes = await file.readAsBytes();
          size = bytes.length;
        } catch (_) {
          // Keep null if unreadable
        }
      }

      // Check empty file
      if (size != null && size == 0) {
        setState(() {
          selectedFile = null;
          selectedFileSize = null;
          errorMessage =
              'The selected file is empty. Please select a valid resume.';
        });
        return;
      }

      // Enforce 5 MB maximum file size restriction (5 * 1024 * 1024 bytes)
      if (size != null && size > ResumeExtractorService.maxFileSizeBytes) {
        setState(() {
          selectedFile = null;
          selectedFileSize = null;
          errorMessage = ResumeExtractorService.maxFileSizeErrorMessage;
        });
        return;
      }

      // Valid file within 5 MB limit
      setState(() {
        selectedFile = file;
        selectedFileSize = size;
        errorMessage = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        selectedFile = null;
        selectedFileSize = null;
        errorMessage = 'Failed to pick file: $e';
      });
    }
  }

  // Analyze resume: extract text locally and analyze with Gemini
  Future<void> analyzeResume() async {
    if (selectedFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a resume first.'),
          backgroundColor: AppTheme.accentAmber,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    // Task 1: Check build-time configured Gemini API key automatically without prompting user
    if (!GeminiConfig.hasApiKey) {
      setState(() {
        errorMessage =
            'Gemini API key is not configured. Please launch the app with --dart-define=GEMINI_API_KEY=your_key';
      });
      return;
    }

    // Task 2: Re-enforce 5 MB limit guard before extraction
    if (selectedFileSize != null &&
        selectedFileSize! > ResumeExtractorService.maxFileSizeBytes) {
      setState(() {
        errorMessage = ResumeExtractorService.maxFileSizeErrorMessage;
      });
      return;
    }

    setState(() {
      isAnalyzing = true;
      errorMessage = null;
      currentStatusMessage = 'Extracting resume text locally...';
    });

    try {
      // Step 1: Local text extraction (PDF / DOCX) with 5 MB guard
      final String extractedText = await ResumeExtractorService.extractText(
        selectedFile!,
      );

      if (!mounted) return;

      // Step 2: Send extracted text to Gemini API
      setState(() {
        currentStatusMessage = 'Analyzing resume with Gemini AI...';
      });

      final ResumeAnalysisModel result = await _geminiService.analyzeResume(
        extractedText,
      );

      if (!mounted) return;

      // In-memory cache for session display
      setState(() {
        isAnalyzing = false;
        lastAnalysis = result;
        lastAnalyzedFileName = selectedFile!.name;
        currentStatusMessage = '';
      });

      // Navigate to structured results screen
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ResumeAnalysisScreen(
            analysis: result,
            fileName: selectedFile!.name,
          ),
        ),
      );
    } on ResumeExtractorException catch (e) {
      if (!mounted) return;
      setState(() {
        isAnalyzing = false;
        errorMessage = e.message;
        currentStatusMessage = '';
      });
    } on GeminiApiException catch (e) {
      if (!mounted) return;
      setState(() {
        isAnalyzing = false;
        errorMessage = e.message;
        currentStatusMessage = '';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        isAnalyzing = false;
        errorMessage = 'An unexpected error occurred: $e';
        currentStatusMessage = '';
      });
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes <= 0) return '0 B';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Resume Analysis'),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: AppTheme.colorfulBackgroundGradient,
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 768;
              final horizontalPadding = isWide ? 40.0 : 20.0;

              return Center(
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(
                    horizontal: horizontalPadding,
                    vertical: 24,
                  ),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1000),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Hero Card with Gradient
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            gradient: AppTheme.heroGradient,
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.primaryBlue.withValues(
                                  alpha: 0.28,
                                ),
                                blurRadius: 18,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(
                                        alpha: 0.18,
                                      ),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.auto_awesome_rounded,
                                      color: Colors.white,
                                      size: 22,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  const Expanded(
                                    child: Text(
                                      'AI-Powered Resume Review',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: -0.3,
                                      ),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppTheme.accentTeal.withValues(
                                        alpha: 0.25,
                                      ),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: Colors.white.withValues(
                                          alpha: 0.3,
                                        ),
                                      ),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.bolt_rounded,
                                          color: Color(0xFF6EE7B7),
                                          size: 14,
                                        ),
                                        SizedBox(width: 4),
                                        Text(
                                          'Gemini AI',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              const Text(
                                'Upload your resume in PDF or DOCX format (up to 5 MB) for instant ATS scoring, demonstrated skills, and actionable improvement suggestions.',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 13.5,
                                  height: 1.45,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Upload Box Area
                        InkWell(
                          onTap: isAnalyzing ? null : selectResume,
                          borderRadius: BorderRadius.circular(22),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              vertical: 32,
                              horizontal: 20,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(22),
                              border: Border.all(
                                color: AppTheme.primaryBlue.withValues(
                                  alpha: 0.28,
                                ),
                                width: 1.5,
                              ),
                              boxShadow: AppTheme.softShadow,
                            ),
                            child: Column(
                              children: [
                                Container(
                                  width: 72,
                                  height: 72,
                                  decoration: BoxDecoration(
                                    color: AppTheme.primaryBlue.withValues(
                                      alpha: 0.08,
                                    ),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.cloud_upload_outlined,
                                    size: 38,
                                    color: AppTheme.primaryBlue,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                const Text(
                                  'Click or tap to select your resume',
                                  style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.darkNavy,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                const Text(
                                  'Text-based documents only (PDF or DOCX, max 5 MB)',
                                  style: TextStyle(
                                    color: AppTheme.textSecondary,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                // Supported format pills
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: const [
                                    _FormatBadge(
                                      label: '.PDF',
                                      color: Color(0xFFEF4444),
                                    ),
                                    SizedBox(width: 8),
                                    _FormatBadge(
                                      label: '.DOCX',
                                      color: Color(0xFF2563EB),
                                    ),
                                    SizedBox(width: 8),
                                    _FormatBadge(
                                      label: 'MAX 5 MB',
                                      color: Color(0xFF0D9488),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 18),
                                OutlinedButton.icon(
                                  onPressed: isAnalyzing ? null : selectResume,
                                  icon: const Icon(Icons.folder_open_rounded),
                                  label: const Text('Browse Files'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: AppTheme.primaryBlue,
                                    side: const BorderSide(
                                      color: AppTheme.primaryBlue,
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 22,
                                      vertical: 12,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        // Selected file card
                        if (selectedFile != null) ...[
                          const SizedBox(height: 20),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: AppTheme.primaryBlue.withValues(
                                  alpha: 0.25,
                                ),
                              ),
                              boxShadow: AppTheme.softShadow,
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 50,
                                  height: 50,
                                  decoration: BoxDecoration(
                                    color:
                                        (selectedFile!.extension
                                                        ?.toLowerCase() ==
                                                    'pdf'
                                                ? AppTheme.accentRose
                                                : AppTheme.primaryBlue)
                                            .withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                    Icons.description_rounded,
                                    color:
                                        selectedFile!.extension
                                                ?.toLowerCase() ==
                                            'pdf'
                                        ? AppTheme.accentRose
                                        : AppTheme.primaryBlue,
                                    size: 28,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        selectedFile!.name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 14.5,
                                          color: AppTheme.textDark,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 6,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: AppTheme.surfaceLight,
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              (selectedFile!.extension ??
                                                      'FILE')
                                                  .toUpperCase(),
                                              style: const TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                                color: AppTheme.textSecondary,
                                              ),
                                            ),
                                          ),
                                          if (selectedFileSize != null &&
                                              selectedFileSize! > 0) ...[
                                            const SizedBox(width: 8),
                                            Text(
                                              _formatFileSize(
                                                selectedFileSize!,
                                              ),
                                              style: const TextStyle(
                                                color: AppTheme.textMuted,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  tooltip: 'Remove selected file',
                                  onPressed: isAnalyzing
                                      ? null
                                      : () {
                                          setState(() {
                                            selectedFile = null;
                                            selectedFileSize = null;
                                            errorMessage = null;
                                          });
                                        },
                                  icon: const Icon(
                                    Icons.close_rounded,
                                    color: AppTheme.textMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],

                        // Error State Alert
                        if (errorMessage != null) ...[
                          const SizedBox(height: 18),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppTheme.accentRose.withValues(
                                alpha: 0.08,
                              ),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: AppTheme.accentRose.withValues(
                                  alpha: 0.35,
                                ),
                              ),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(
                                  Icons.error_outline_rounded,
                                  color: AppTheme.accentRose,
                                  size: 22,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Unable to analyze resume',
                                        style: TextStyle(
                                          color: AppTheme.accentRose,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        errorMessage!,
                                        style: const TextStyle(
                                          color: AppTheme.textDark,
                                          fontSize: 13,
                                          height: 1.35,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],

                        // Loading State Display
                        if (isAnalyzing) ...[
                          const SizedBox(height: 20),
                          Container(
                            padding: const EdgeInsets.all(22),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryBlue.withValues(
                                alpha: 0.05,
                              ),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: AppTheme.primaryBlue.withValues(
                                  alpha: 0.22,
                                ),
                              ),
                            ),
                            child: Column(
                              children: [
                                const SizedBox(
                                  width: 32,
                                  height: 32,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 3,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      AppTheme.primaryBlue,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 14),
                                Text(
                                  currentStatusMessage,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.primaryBlue,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  'Processing locally and in-memory with Gemini AI...',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppTheme.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],

                        const SizedBox(height: 24),

                        // Primary Action Button: Analyze Resume with AI
                        Container(
                          height: 52,
                          decoration: BoxDecoration(
                            gradient: selectedFile != null && !isAnalyzing
                                ? AppTheme.primaryGradient
                                : null,
                            color: selectedFile == null || isAnalyzing
                                ? Colors.grey.shade300
                                : null,
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: selectedFile != null && !isAnalyzing
                                ? [
                                    BoxShadow(
                                      color: AppTheme.primaryBlue.withValues(
                                        alpha: 0.35,
                                      ),
                                      blurRadius: 12,
                                      offset: const Offset(0, 5),
                                    ),
                                  ]
                                : null,
                          ),
                          child: ElevatedButton.icon(
                            onPressed: isAnalyzing || selectedFile == null
                                ? null
                                : analyzeResume,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            icon: isAnalyzing
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(
                                    Icons.auto_awesome_rounded,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                            label: Text(
                              isAnalyzing
                                  ? 'Analyzing...'
                                  : 'Analyze Resume with AI',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),

                        // View Previous Analysis Button (In-memory session result)
                        if (lastAnalysis != null && !isAnalyzing) ...[
                          const SizedBox(height: 12),
                          OutlinedButton.icon(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => ResumeAnalysisScreen(
                                    analysis: lastAnalysis!,
                                    fileName: lastAnalyzedFileName ?? 'Resume',
                                  ),
                                ),
                              );
                            },
                            icon: const Icon(
                              Icons.analytics_outlined,
                              color: AppTheme.primaryBlue,
                              size: 20,
                            ),
                            label: Text(
                              'View Last Analysis Result (${lastAnalysis!.score}/100)',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppTheme.primaryBlue,
                              side: const BorderSide(
                                color: AppTheme.primaryBlue,
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                          ),
                        ],

                        const SizedBox(height: 24),

                        // Privacy Information Card
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppTheme.surfaceLight,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppTheme.borderLight),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              Icon(
                                Icons.verified_user_outlined,
                                color: AppTheme.accentTeal,
                                size: 20,
                              ),
                              SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Privacy Guarantee: Your resume text is processed locally and in-memory for Gemini analysis. Resume contents and analysis results are never stored in Firestore or cloud storage.',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppTheme.textSecondary,
                                    height: 1.45,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _FormatBadge extends StatelessWidget {
  final String label;
  final Color color;

  const _FormatBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../models/mock_interview_model.dart';
import '../../services/mock_interview_service.dart';
import '../../theme/app_theme.dart';
import 'interview_result_screen.dart';

class InterviewSessionScreen extends StatefulWidget {
  final String role;
  final String difficulty;
  final String type;
  final int questionCount;

  const InterviewSessionScreen({
    super.key,
    required this.role,
    required this.difficulty,
    required this.type,
    this.questionCount = 5,
  });

  @override
  State<InterviewSessionScreen> createState() => _InterviewSessionScreenState();
}

class _InterviewSessionScreenState extends State<InterviewSessionScreen> {
  final MockInterviewService _service = MockInterviewService();
  final TextEditingController _answerController = TextEditingController();

  List<MockInterviewQuestion> _questions = [];
  final List<MockInterviewAnswer> _recordedAnswers = [];

  bool _isLoadingQuestions = true;
  bool _isEvaluating = false;
  int _currentIndex = 0;
  MockInterviewAnswer? _currentEvaluation;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _loadQuestions();
  }

  @override
  void dispose() {
    _answerController.dispose();
    super.dispose();
  }

  Future<void> _loadQuestions() async {
    setState(() {
      _isLoadingQuestions = true;
      _errorMessage = '';
    });

    try {
      final questions = await _service.getQuestions(
        role: widget.role,
        difficulty: widget.difficulty,
        type: widget.type,
        count: widget.questionCount,
      );

      if (mounted) {
        setState(() {
          _questions = questions;
          _isLoadingQuestions = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to prepare interview session: $e';
          _isLoadingQuestions = false;
        });
      }
    }
  }

  Future<void> _submitAnswer() async {
    final text = _answerController.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter your response before submitting.'),
          backgroundColor: AppTheme.amber,
        ),
      );
      return;
    }

    setState(() {
      _isEvaluating = true;
    });

    try {
      final currentQuestion = _questions[_currentIndex];
      final evaluation = await _service.evaluateAnswer(
        question: currentQuestion,
        userAnswer: text,
      );

      if (mounted) {
        setState(() {
          _currentEvaluation = evaluation;
          _recordedAnswers.add(evaluation);
          _isEvaluating = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isEvaluating = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Evaluation error: $e'),
            backgroundColor: AppTheme.rose,
          ),
        );
      }
    }
  }

  void _nextQuestion() {
    if (_currentIndex + 1 < _questions.length) {
      setState(() {
        _currentIndex++;
        _currentEvaluation = null;
        _answerController.clear();
      });
    } else {
      _finalizeInterviewSession();
    }
  }

  Future<void> _finalizeInterviewSession() async {
    // Calculate overall score (average of answers mapped to 100)
    int totalScore = 0;
    final Map<String, List<int>> categoryScores = {};

    for (final ans in _recordedAnswers) {
      totalScore += ans.score;
      categoryScores.putIfAbsent(ans.category, () => []).add(ans.score);
    }

    final double avgScore10 = _recordedAnswers.isNotEmpty
        ? totalScore / _recordedAnswers.length
        : 7.0;
    final int overallScore100 = (avgScore10 * 10).round().clamp(10, 100);

    final Map<String, double> categoryBreakdown = {};
    categoryScores.forEach((cat, scores) {
      final double catAvg = scores.reduce((a, b) => a + b) / scores.length;
      categoryBreakdown[cat] = double.parse(catAvg.toStringAsFixed(1));
    });

    // Generate personalized recommendations
    final recommendations = <String>[];
    if (overallScore100 >= 80) {
      recommendations.add(
        'Great job! Continue refining system design edge-cases and architectural trade-offs.',
      );
      recommendations.add(
        'Review the practical capstone projects in your Career Roadmap to polish portfolio demonstrations.',
      );
    } else if (overallScore100 >= 60) {
      recommendations.add(
        'Practice framing responses using the STAR method (Situation, Task, Action, Result) for added clarity.',
      );
      recommendations.add(
        'Revisit Stage 2 & 3 topics in your Career Roadmap to deepen technical explanations.',
      );
    } else {
      recommendations.add(
        'Focus on core fundamentals and key vocabulary in your target stack.',
      );
      recommendations.add(
        'Work through the step-by-step topics in your Personalized Roadmap before taking mock interviews.',
      );
    }

    final session = MockInterviewSession(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      role: widget.role,
      difficulty: widget.difficulty,
      type: widget.type,
      totalQuestions: _recordedAnswers.length,
      overallScore: overallScore100,
      completedAt: DateTime.now(),
      answers: _recordedAnswers,
      categoryBreakdown: categoryBreakdown,
      recommendations: recommendations,
    );

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null && uid.isNotEmpty) {
      try {
        await _service.saveSession(uid, session);
      } catch (_) {
        // Continue to result screen even if Firestore fails
      }
    }

    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => InterviewResultScreen(session: session),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingQuestions) {
      return Scaffold(
        appBar: AppBar(title: const Text('AI Mock Interview')),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text(
                'Preparing your customized interview session...',
                style: TextStyle(color: AppTheme.textMedium, fontSize: 13.5),
              ),
            ],
          ),
        ),
      );
    }

    if (_errorMessage.isNotEmpty || _questions.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('AI Mock Interview')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.error_outline_rounded,
                  size: 56,
                  color: AppTheme.rose,
                ),
                const SizedBox(height: 16),
                Text(
                  _errorMessage.isNotEmpty
                      ? _errorMessage
                      : 'No questions could be loaded.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 14.5),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _loadQuestions,
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final currentQuestion = _questions[_currentIndex];
    final progress = (_currentIndex + 1) / _questions.length;
    final isLastQuestion = _currentIndex + 1 == _questions.length;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Question ${_currentIndex + 1} of ${_questions.length}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: LinearProgressIndicator(
            value: progress,
            backgroundColor: const Color(0xFFE2E8F0),
            valueColor: const AlwaysStoppedAnimation<Color>(
              AppTheme.primaryBlue,
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // METADATA BADGES
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      currentQuestion.category,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryBlue,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.teal.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      widget.difficulty,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.teal,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // QUESTION CARD
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: AppTheme.primaryBlue.withValues(alpha: 0.2),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0F172A).withValues(alpha: 0.04),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(
                          Icons.help_outline_rounded,
                          color: AppTheme.primaryBlue,
                          size: 20,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Interview Prompt',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryBlue,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      currentQuestion.question,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textDark,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // CANDIDATE ANSWER FIELD
              const Text(
                'Your Answer',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textDark,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _answerController,
                maxLines: 7,
                enabled: _currentEvaluation == null && !_isEvaluating,
                decoration: InputDecoration(
                  hintText:
                      'Type your detailed answer here as if speaking to an interviewer. Explain your thought process, principles, and trade-offs...',
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.all(16),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // SUBMIT BUTTON / EVALUATING SPINNER
              if (_currentEvaluation == null) ...[
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _isEvaluating ? null : _submitAnswer,
                    child: _isEvaluating
                        ? const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: Colors.white,
                                ),
                              ),
                              SizedBox(width: 12),
                              Text('Evaluating with AI Rubric...'),
                            ],
                          )
                        : const Text(
                            'Submit Answer for Feedback',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
              ],

              // LIVE EVALUATION FEEDBACK CARD
              if (_currentEvaluation != null) ...[
                const SizedBox(height: 10),
                _buildLiveEvaluationCard(_currentEvaluation!),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: _nextQuestion,
                    icon: Icon(
                      isLastQuestion
                          ? Icons.emoji_events_outlined
                          : Icons.arrow_forward_rounded,
                      size: 20,
                    ),
                    label: Text(
                      isLastQuestion
                          ? 'Finish Interview & View Scorecard'
                          : 'Proceed to Next Question',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF059669),
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLiveEvaluationCard(MockInterviewAnswer eval) {
    Color scoreColor = const Color(0xFF059669);
    if (eval.score <= 4) {
      scoreColor = AppTheme.rose;
    } else if (eval.score <= 7) {
      scoreColor = AppTheme.primaryBlue;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFCBD5E1)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Evaluation Feedback',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textDark,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: scoreColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: scoreColor.withValues(alpha: 0.3)),
                ),
                child: Text(
                  'Score: ${eval.score} / 10',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.bold,
                    color: scoreColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Strengths
          if (eval.strengths.isNotEmpty) ...[
            const Row(
              children: [
                Icon(
                  Icons.check_circle_rounded,
                  size: 16,
                  color: Color(0xFF059669),
                ),
                SizedBox(width: 6),
                Text(
                  'Strengths Noted:',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF059669),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            ...eval.strengths.map(
              (s) => Padding(
                padding: const EdgeInsets.only(left: 22, bottom: 4),
                child: Text(
                  '• $s',
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: AppTheme.textDark,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
          ],

          // Improvements
          if (eval.improvements.isNotEmpty) ...[
            const Row(
              children: [
                Icon(
                  Icons.lightbulb_outline_rounded,
                  size: 16,
                  color: AppTheme.amber,
                ),
                SizedBox(width: 6),
                Text(
                  'Areas for Improvement:',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.amber,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            ...eval.improvements.map(
              (imp) => Padding(
                padding: const EdgeInsets.only(left: 22, bottom: 4),
                child: Text(
                  '• $imp',
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: AppTheme.textDark,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
          ],

          // Exemplary Answer
          if (eval.modelAnswer.isNotEmpty) ...[
            Theme(
              data: Theme.of(
                context,
              ).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: const Text(
                  'View Exemplary Model Answer',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryBlue,
                  ),
                ),
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryBlue.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: AppTheme.primaryBlue.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Text(
                      eval.modelAnswer,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppTheme.darkBlue,
                        height: 1.45,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

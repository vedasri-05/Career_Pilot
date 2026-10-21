import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../models/mock_interview_model.dart';
import '../../services/mock_interview_service.dart';
import '../../theme/app_theme.dart';
import 'interview_result_screen.dart';
import 'interview_setup_screen.dart';

class InterviewHubScreen extends StatefulWidget {
  const InterviewHubScreen({super.key});

  @override
  State<InterviewHubScreen> createState() => _InterviewHubScreenState();
}

class _InterviewHubScreenState extends State<InterviewHubScreen> {
  final MockInterviewService _service = MockInterviewService();

  User? get _currentUser => FirebaseAuth.instance.currentUser;

  Color _getScoreColor(int score) {
    if (score >= 80) return const Color(0xFF059669);
    if (score >= 65) return AppTheme.primaryBlue;
    if (score >= 50) return AppTheme.amber;
    return AppTheme.rose;
  }

  void _openSetup() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const InterviewSetupScreen()),
    );
  }

  void _viewSessionDetails(MockInterviewSession session) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => InterviewResultScreen(session: session),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final uid = _currentUser?.uid ?? '';

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'AI Mock Interviews',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: StreamBuilder<List<MockInterviewSession>>(
          stream: uid.isNotEmpty
              ? _service.getSessionsStream(uid)
              : const Stream.empty(),
          builder: (context, snapshot) {
            final sessions = snapshot.data ?? [];

            // Calculate aggregate stats
            int totalSessions = sessions.length;
            int avgScore = 0;
            if (sessions.isNotEmpty) {
              final sum = sessions.fold<int>(
                0,
                (prev, s) => prev + s.overallScore,
              );
              avgScore = (sum / sessions.length).round();
            }

            return SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // HERO START CARD
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppTheme.primaryBlue, AppTheme.darkBlue],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primaryBlue.withValues(alpha: 0.3),
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
                                color: Colors.white.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.record_voice_over_rounded,
                                color: Colors.white,
                                size: 26,
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'AI Interview Simulator',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 19,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  SizedBox(height: 2),
                                  Text(
                                    'Tailored to your target career position',
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 12.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Practice real-world technical and behavioral interview questions with instantaneous scoring, feedback, and model answers.',
                          style: TextStyle(
                            color: Color(0xFFE2E8F0),
                            fontSize: 13.5,
                            height: 1.45,
                          ),
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _openSetup,
                            icon: const Icon(
                              Icons.play_arrow_rounded,
                              size: 20,
                            ),
                            label: const Text('Start New Mock Interview'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: AppTheme.primaryBlue,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              textStyle: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // STATS ROW
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          title: 'Total Sessions',
                          value: '$totalSessions',
                          icon: Icons.checklist_rounded,
                          color: AppTheme.primaryBlue,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildStatCard(
                          title: 'Average Score',
                          value: totalSessions > 0 ? '$avgScore%' : '--',
                          icon: Icons.speed_rounded,
                          color: totalSessions > 0
                              ? _getScoreColor(avgScore)
                              : Colors.grey,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 28),

                  // PAST SESSIONS HEADER
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Past Interview Sessions',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textDark,
                        ),
                      ),
                      if (sessions.isNotEmpty)
                        Text(
                          '$totalSessions completed',
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: AppTheme.textMedium,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                    ],
                  ),

                  const SizedBox(height: 14),

                  // PAST SESSIONS LIST / EMPTY STATE
                  if (sessions.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(28),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                              color: AppTheme.primaryBlue.withValues(
                                alpha: 0.08,
                              ),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.history_rounded,
                              size: 32,
                              color: AppTheme.primaryBlue,
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'No interview sessions yet',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textDark,
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Take your first mock interview to benchmark your readiness and get AI-powered feedback.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: AppTheme.textMedium,
                              fontSize: 13,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 18),
                          OutlinedButton.icon(
                            onPressed: _openSetup,
                            icon: const Icon(Icons.add, size: 16),
                            label: const Text('Configure First Session'),
                          ),
                        ],
                      ),
                    )
                  else
                    ...sessions.map((session) => _buildSessionTile(session)),

                  const SizedBox(height: 20),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.textMedium,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSessionTile(MockInterviewSession session) {
    final scoreColor = _getScoreColor(session.overallScore);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        onTap: () => _viewSessionDetails(session),
        leading: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: scoreColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: scoreColor.withValues(alpha: 0.3)),
          ),
          child: Center(
            child: Text(
              '${session.overallScore}%',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: scoreColor,
              ),
            ),
          ),
        ),
        title: Text(
          session.role,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: AppTheme.textDark,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Row(
              children: [
                Text(
                  '${session.difficulty} • ${session.type}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.textMedium,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '• ${_formatDate(session.completedAt)}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.textMedium,
                  ),
                ),
              ],
            ),
          ],
        ),
        trailing: const Icon(
          Icons.arrow_forward_ios_rounded,
          size: 14,
          color: Colors.grey,
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}

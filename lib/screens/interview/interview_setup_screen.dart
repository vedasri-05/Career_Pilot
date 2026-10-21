import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../services/firestore_service.dart';
import '../../theme/app_theme.dart';
import 'interview_session_screen.dart';

class InterviewSetupScreen extends StatefulWidget {
  final String? initialRole;

  const InterviewSetupScreen({super.key, this.initialRole});

  @override
  State<InterviewSetupScreen> createState() => _InterviewSetupScreenState();
}

class _InterviewSetupScreenState extends State<InterviewSetupScreen> {
  String _selectedRole = 'Flutter Developer';
  String _selectedDifficulty = 'Mid-Level';
  String _selectedType = 'Mixed';
  int _questionCount = 5;
  bool _isVoiceMode = true; // Voice Assistant enabled by default

  final List<String> _availableRoles = [
    'Flutter Developer',
    'Software Developer',
    'Web Developer',
    'Data Analyst',
    'Data Scientist',
    'Mobile App Developer',
    'Product Manager',
    'DevOps Engineer',
  ];

  final List<String> _difficulties = [
    'Beginner / Entry',
    'Mid-Level',
    'Senior',
  ];

  final List<Map<String, String>> _interviewTypes = [
    {
      'type': 'Technical',
      'desc': 'Core language concepts, data structures, and architecture.',
      'icon': 'code',
    },
    {
      'type': 'Behavioral',
      'desc': 'STAR-method situational, teamwork, and leadership questions.',
      'icon': 'psychology',
    },
    {
      'type': 'Mixed',
      'desc': 'Balanced mix of technical knowledge and behavioral scenarios.',
      'icon': 'auto_awesome',
    },
  ];

  @override
  void initState() {
    super.initState();
    if (widget.initialRole != null && widget.initialRole!.isNotEmpty) {
      if (_availableRoles.contains(widget.initialRole)) {
        _selectedRole = widget.initialRole!;
      }
    } else {
      _loadUserRole();
    }
  }

  Future<void> _loadUserRole() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        final profile = await FirestoreService().getUserProfile(user.uid);
        if (profile != null && profile.careerGoal.isNotEmpty && mounted) {
          final goal = profile.careerGoal;
          if (_availableRoles.contains(goal)) {
            setState(() {
              _selectedRole = goal;
            });
          } else if (goal.toLowerCase().contains('web')) {
            setState(() {
              _selectedRole = 'Web Developer';
            });
          } else if (goal.toLowerCase().contains('data')) {
            setState(() {
              _selectedRole = 'Data Analyst';
            });
          }
        }
      } catch (_) {}
    }
  }

  void _startInterview() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => InterviewSessionScreen(
          role: _selectedRole,
          difficulty: _selectedDifficulty,
          type: _selectedType,
          questionCount: _questionCount,
          isVoiceMode: _isVoiceMode,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Mock Interview Setup',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // BANNER
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppTheme.primaryBlue, AppTheme.darkBlue],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primaryBlue.withValues(alpha: 0.25),
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.record_voice_over_rounded,
                          color: Colors.white,
                          size: 26,
                        ),
                        SizedBox(width: 10),
                        Text(
                          'Configure Your Simulation',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Tailor your question set and difficulty to mirror authentic technical and HR screening interviews.',
                      style: TextStyle(
                        color: Color(0xFFE2E8F0),
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // 1. TARGET ROLE
              const Text(
                '1. Target Position',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textDark,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedRole,
                    isExpanded: true,
                    icon: const Icon(
                      Icons.arrow_drop_down,
                      color: AppTheme.primaryBlue,
                    ),
                    items: _availableRoles.map((role) {
                      return DropdownMenuItem(
                        value: role,
                        child: Text(
                          role,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textDark,
                          ),
                        ),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedRole = val);
                    },
                  ),
                ),
              ),

              const SizedBox(height: 22),

              // INTERACTION MODE (VOICE VS TEXT)
              const Text(
                '2. Interview Format',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textDark,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => setState(() => _isVoiceMode = true),
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: _isVoiceMode
                              ? AppTheme.primaryBlue.withValues(alpha: 0.08)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: _isVoiceMode
                                ? AppTheme.primaryBlue
                                : const Color(0xFFE2E8F0),
                            width: _isVoiceMode ? 2 : 1,
                          ),
                        ),
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: _isVoiceMode
                                    ? AppTheme.primaryBlue
                                    : const Color(0xFFF1F5F9),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.mic_rounded,
                                color: _isVoiceMode
                                    ? Colors.white
                                    : AppTheme.textDark,
                                size: 22,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Voice Assistant',
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textDark,
                              ),
                            ),
                            const SizedBox(height: 3),
                            const Text(
                              'Spoken Q&A',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppTheme.textMedium,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: InkWell(
                      onTap: () => setState(() => _isVoiceMode = false),
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: !_isVoiceMode
                              ? AppTheme.primaryBlue.withValues(alpha: 0.08)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: !_isVoiceMode
                                ? AppTheme.primaryBlue
                                : const Color(0xFFE2E8F0),
                            width: !_isVoiceMode ? 2 : 1,
                          ),
                        ),
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: !_isVoiceMode
                                    ? AppTheme.primaryBlue
                                    : const Color(0xFFF1F5F9),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.keyboard_alt_outlined,
                                color: !_isVoiceMode
                                    ? Colors.white
                                    : AppTheme.textDark,
                                size: 22,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Text Mode',
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textDark,
                              ),
                            ),
                            const SizedBox(height: 3),
                            const Text(
                              'Written Q&A',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppTheme.textMedium,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 22),

              // 3. DIFFICULTY
              const Text(
                '3. Experience / Seniority Level',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textDark,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: _difficulties.map((diff) {
                  final isSelected = _selectedDifficulty == diff;
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: ChoiceChip(
                        label: Text(
                          diff.split(' ').first,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: isSelected
                                ? Colors.white
                                : AppTheme.textDark,
                          ),
                        ),
                        selected: isSelected,
                        selectedColor: AppTheme.primaryBlue,
                        backgroundColor: Colors.white,
                        onSelected: (selected) {
                          if (selected) {
                            setState(() => _selectedDifficulty = diff);
                          }
                        },
                      ),
                    ),
                  );
                }).toList(),
              ),

              const SizedBox(height: 22),

              // 4. INTERVIEW TYPE
              const Text(
                '4. Interview Style',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textDark,
                ),
              ),
              const SizedBox(height: 8),
              ..._interviewTypes.map((typeMap) {
                final type = typeMap['type']!;
                final desc = typeMap['desc']!;
                final isSelected = _selectedType == type;

                return InkWell(
                  onTap: () => setState(() => _selectedType = type),
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppTheme.primaryBlue.withValues(alpha: 0.06)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isSelected
                            ? AppTheme.primaryBlue
                            : const Color(0xFFE2E8F0),
                        width: isSelected ? 1.5 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isSelected
                              ? Icons.radio_button_checked
                              : Icons.radio_button_off,
                          color: isSelected
                              ? AppTheme.primaryBlue
                              : Colors.grey,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                type,
                                style: TextStyle(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.bold,
                                  color: isSelected
                                      ? AppTheme.primaryBlue
                                      : AppTheme.textDark,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                desc,
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
                  ),
                );
              }),

              const SizedBox(height: 20),

              // 5. QUESTION COUNT
              const Text(
                '5. Number of Questions',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textDark,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [3, 5, 10].map((count) {
                  final isSelected = _questionCount == count;
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: InkWell(
                        onTap: () => setState(() => _questionCount = count),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppTheme.primaryBlue
                                : Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected
                                  ? AppTheme.primaryBlue
                                  : const Color(0xFFE2E8F0),
                            ),
                          ),
                          child: Center(
                            child: Text(
                              '$count Questions',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: isSelected
                                    ? Colors.white
                                    : AppTheme.textDark,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),

              const SizedBox(height: 32),

              // START BUTTON
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _startInterview,
                  icon: const Icon(Icons.play_arrow_rounded, size: 22),
                  label: const Text(
                    'Begin Interview',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}

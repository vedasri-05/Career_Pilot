import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../models/career_path_profile.dart';
import '../../services/firestore_service.dart';
import '../../services/roadmap_service.dart';
import '../../theme/app_theme.dart';
import 'roadmap_screen.dart';

class CareerPathFormScreen extends StatefulWidget {
  const CareerPathFormScreen({super.key});

  @override
  State<CareerPathFormScreen> createState() => _CareerPathFormScreenState();
}

class _CareerPathFormScreenState extends State<CareerPathFormScreen> {
  final _formKey = GlobalKey<FormState>();

  String selectedRole = 'Flutter Developer';
  String selectedEducation = "Bachelor's Degree";
  String selectedExperience = 'Beginner / Entry Level';
  int selectedWeeklyHours = 10;

  final TextEditingController _customSkillController = TextEditingController();
  final List<String> userSkills = [];

  // Available roles matching the rule-based roadmap engine
  final List<String> availableRoles = [
    'Flutter Developer',
    'Web Developer',
    'Data Analyst',
    'Software Engineer',
  ];

  // Common quick-pick skill suggestions based on role
  final Map<String, List<String>> roleSuggestedSkills = {
    'Flutter Developer': [
      'Dart',
      'Flutter',
      'Firebase',
      'REST APIs',
      'Git',
      'Provider',
      'BLoC',
      'SQLite',
    ],
    'Web Developer': [
      'HTML/CSS',
      'JavaScript',
      'React',
      'Node.js',
      'TypeScript',
      'Git',
      'Tailwind CSS',
      'SQL',
    ],
    'Data Analyst': [
      'Excel',
      'SQL',
      'Python',
      'Pandas',
      'Power BI',
      'Tableau',
      'Statistics',
      'Google Sheets',
    ],
    'Software Engineer': [
      'Git',
      'OOP',
      'Data Structures',
      'Algorithms',
      'Python',
      'Java',
      'Docker',
      'Linux',
    ],
  };

  final List<String> educationLevels = [
    "High School",
    "Bachelor's Degree",
    "Master's Degree",
    "Bootcamp / Self-Taught",
    "Other",
  ];

  final List<String> experienceLevels = [
    'Beginner / Entry Level',
    'Intermediate',
    'Advanced',
  ];

  final List<int> learningTimeOptions = [5, 10, 15, 20];

  @override
  void initState() {
    super.initState();
    // If a roadmap was previously generated, prefill from that profile
    final existing = RoadmapService.currentRoadmap?.profile;
    if (existing != null) {
      selectedRole = existing.targetRole;
      selectedEducation = existing.education;
      selectedExperience = existing.experienceLevel;
      selectedWeeklyHours = existing.weeklyHours;
      userSkills.addAll(existing.skills);
    } else {
      _prefillFromUserProfile();
    }
  }

  Future<void> _prefillFromUserProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        final profile = await FirestoreService().getUserProfile(user.uid);
        if (profile != null && profile.careerGoal.isNotEmpty && mounted) {
          final mappedRole = _mapCareerGoalToRole(profile.careerGoal);
          setState(() {
            selectedRole = mappedRole;
          });
        }
      } catch (_) {}
    }
  }

  String _mapCareerGoalToRole(String goal) {
    final lower = goal.toLowerCase();
    if (lower.contains('web')) return 'Web Developer';
    if (lower.contains('data')) return 'Data Analyst';
    if (lower.contains('software') ||
        lower.contains('cloud') ||
        lower.contains('devops')) {
      return 'Software Engineer';
    }
    return 'Flutter Developer';
  }

  @override
  void dispose() {
    _customSkillController.dispose();
    super.dispose();
  }

  void _addSkill(String skill) {
    final trimmed = skill.trim();
    if (trimmed.isNotEmpty &&
        !userSkills.any((s) => s.toLowerCase() == trimmed.toLowerCase())) {
      setState(() {
        userSkills.add(trimmed);
      });
      _customSkillController.clear();
    }
  }

  void _removeSkill(String skill) {
    setState(() {
      userSkills.remove(skill);
    });
  }

  Future<void> _generateRoadmap() async {
    if (!_formKey.currentState!.validate()) return;

    final profile = CareerPathProfile(
      targetRole: selectedRole,
      education: selectedEducation,
      skills: List.from(userSkills),
      experienceLevel: selectedExperience,
      weeklyHours: selectedWeeklyHours,
    );

    final roadmap = RoadmapService.generateRoadmap(profile);

    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await RoadmapService.saveUserRoadmap(user.uid, roadmap);
    }

    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => RoadmapScreen(roadmap: roadmap),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final suggested = roleSuggestedSkills[selectedRole] ?? [];

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Career Path & Roadmap',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // HEADER CARD
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppTheme.primaryBlue, AppTheme.darkBlue],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primaryBlue.withValues(alpha: 0.25),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.route, color: Colors.white, size: 28),
                          SizedBox(width: 10),
                          Text(
                            'Personalized Learning Path',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Customize your target role, existing knowledge, and weekly commitment to generate an actionable step-by-step roadmap.',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // 1. TARGET ROLE
                _buildSectionTitle('1. Target Career Role'),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: selectedRole,
                      isExpanded: true,
                      icon: const Icon(
                        Icons.arrow_drop_down,
                        color: AppTheme.primaryBlue,
                      ),
                      items: availableRoles.map((role) {
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
                      onChanged: (newRole) {
                        if (newRole != null) {
                          setState(() {
                            selectedRole = newRole;
                          });
                        }
                      },
                    ),
                  ),
                ),

                const SizedBox(height: 22),

                // 2. EDUCATION LEVEL
                _buildSectionTitle('2. Education Level'),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: selectedEducation,
                      isExpanded: true,
                      items: educationLevels.map((edu) {
                        return DropdownMenuItem(
                          value: edu,
                          child: Text(
                            edu,
                            style: const TextStyle(
                              fontSize: 15,
                              color: AppTheme.textDark,
                            ),
                          ),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() {
                            selectedEducation = val;
                          });
                        }
                      },
                    ),
                  ),
                ),

                const SizedBox(height: 22),

                // 3. EXPERIENCE LEVEL
                _buildSectionTitle('3. Current Experience Level'),
                const SizedBox(height: 8),
                Row(
                  children: experienceLevels.map((exp) {
                    final isSelected = selectedExperience == exp;
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        child: ChoiceChip(
                          label: Text(
                            exp.split(' ').first,
                            style: TextStyle(
                              fontSize: 12.5,
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
                              setState(() {
                                selectedExperience = exp;
                              });
                            }
                          },
                        ),
                      ),
                    );
                  }).toList(),
                ),

                const SizedBox(height: 22),

                // 4. AVAILABLE LEARNING TIME
                _buildSectionTitle('4. Available Learning Time'),
                const SizedBox(height: 4),
                const Text(
                  'How many hours can you dedicate each week?',
                  style: TextStyle(fontSize: 12.5, color: Colors.grey),
                ),
                const SizedBox(height: 10),
                Row(
                  children: learningTimeOptions.map((hours) {
                    final isSelected = selectedWeeklyHours == hours;
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        child: InkWell(
                          onTap: () {
                            setState(() {
                              selectedWeeklyHours = hours;
                            });
                          },
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
                                    : Colors.grey.shade300,
                              ),
                            ),
                            child: Column(
                              children: [
                                Text(
                                  '$hours hrs',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: isSelected
                                        ? Colors.white
                                        : AppTheme.textDark,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'per week',
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    color: isSelected
                                        ? Colors.white70
                                        : Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),

                const SizedBox(height: 22),

                // 5. CURRENT SKILLS (PRESET + CUSTOM)
                _buildSectionTitle('5. Current Skills & Tools'),
                const SizedBox(height: 4),
                const Text(
                  'Select skills you already know; matching roadmap topics will be marked complete.',
                  style: TextStyle(fontSize: 12.5, color: Colors.grey),
                ),
                const SizedBox(height: 10),

                // Quick suggestions for the selected role
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: suggested.map((skill) {
                    final hasSkill = userSkills.any(
                      (s) => s.toLowerCase() == skill.toLowerCase(),
                    );
                    return FilterChip(
                      label: Text(skill),
                      selected: hasSkill,
                      selectedColor: AppTheme.primaryBlue.withValues(
                        alpha: 0.15,
                      ),
                      checkmarkColor: AppTheme.primaryBlue,
                      labelStyle: TextStyle(
                        fontSize: 12,
                        color: hasSkill
                            ? AppTheme.primaryBlue
                            : AppTheme.textDark,
                        fontWeight: hasSkill
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                      onSelected: (selected) {
                        if (selected) {
                          _addSkill(skill);
                        } else {
                          _removeSkill(skill);
                        }
                      },
                    );
                  }).toList(),
                ),

                const SizedBox(height: 12),

                // Custom skill input field
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _customSkillController,
                        decoration: InputDecoration(
                          hintText: 'Add another skill (e.g. Docker, GraphQL)',
                          hintStyle: const TextStyle(fontSize: 13),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                        ),
                        onFieldSubmitted: _addSkill,
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () => _addSkill(_customSkillController.text),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(54, 48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Icon(Icons.add),
                    ),
                  ],
                ),

                // Selected skill tags
                if (userSkills.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: userSkills.map((skill) {
                      return Chip(
                        label: Text(
                          skill,
                          style: const TextStyle(fontSize: 12),
                        ),
                        deleteIcon: const Icon(Icons.close, size: 14),
                        onDeleted: () => _removeSkill(skill),
                        backgroundColor: AppTheme.primaryBlue.withValues(
                          alpha: 0.08,
                        ),
                        side: BorderSide(
                          color: AppTheme.primaryBlue.withValues(alpha: 0.3),
                        ),
                      );
                    }).toList(),
                  ),
                ],

                const SizedBox(height: 32),

                // SUBMIT BUTTON
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton.icon(
                    onPressed: _generateRoadmap,
                    icon: const Icon(Icons.explore_outlined),
                    label: const Text(
                      'Generate Learning Roadmap',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: AppTheme.textDark,
      ),
    );
  }
}

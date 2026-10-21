import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../services/firestore_service.dart';
import '../../services/notification_service.dart';
import '../../services/roadmap_service.dart';
import '../../theme/app_theme.dart';
import '../careers/careers_screen.dart';
import '../interview/interview_hub_screen.dart';
import '../notifications/notifications_screen.dart';
import '../profile/profile_screen.dart';
import '../resume/upload_resume_screen.dart';
import '../roadmap/career_path_form_screen.dart';
import '../roadmap/roadmap_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int selectedIndex = 0;

  User? get currentUser => FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    _initNotifications();
  }

  Future<void> _initNotifications() async {
    final user = currentUser;
    if (user != null) {
      await NotificationService().initialize();
      await NotificationService().syncPeriodicRemindersWithPreferences(
        user.uid,
      );
      final profile = await FirestoreService().getUserProfile(user.uid);
      if (profile != null && profile.careerGoal.isNotEmpty) {
        await NotificationService().checkAndNotifyNewJobs(
          uid: user.uid,
          careerGoal: profile.careerGoal,
        );
      }
    }
  }

  // ==========================================
  // NAVIGATION ACTIONS
  // ==========================================

  void _openNotifications() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const NotificationsScreen()),
    );
  }

  void _openProfile() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ProfileScreen()),
    );
  }

  void _openResume() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const UploadResumeScreen()),
    );
  }

  void _openCareers() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const CareersScreen()),
    );
  }

  Future<void> _openRoadmap() async {
    final cached = RoadmapService.currentRoadmap;
    if (cached != null) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => RoadmapScreen(roadmap: cached)),
      );
      return;
    }

    final user = currentUser;
    if (user != null) {
      final saved = await RoadmapService.loadUserRoadmap(user.uid);
      if (saved != null && mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => RoadmapScreen(roadmap: saved),
          ),
        );
        return;
      }
    }

    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const CareerPathFormScreen()),
      );
    }
  }

  void _openMockInterviews() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const InterviewHubScreen()),
    );
  }

  // ==========================================
  // BUILD
  // ==========================================

  @override
  Widget build(BuildContext context) {
    final pages = [
      _buildHomePage(),
      const UploadResumeScreen(),
      const CareersScreen(),
      const ProfileScreen(),
    ];

    return Scaffold(
      body: pages[selectedIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedIndex,
        onDestinationSelected: (index) {
          setState(() {
            selectedIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.description_outlined),
            selectedIcon: Icon(Icons.description_rounded),
            label: 'Resume',
          ),
          NavigationDestination(
            icon: Icon(Icons.work_outline_rounded),
            selectedIcon: Icon(Icons.work_rounded),
            label: 'Careers',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon: Icon(Icons.person_rounded),
            label: 'Profile',
          ),
        ],
      ),
    );
  }

  // ==========================================
  // HOME PAGE (FULL-SCREEN & COLOURFUL)
  // ==========================================

  Widget _buildHomePage() {
    final user = currentUser;
    final displayName = user?.displayName ?? 'Explorer';

    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: const BoxDecoration(
        gradient: AppTheme.colorfulBackgroundGradient,
      ),
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth > 768;
            final isExtraWide = constraints.maxWidth > 1200;
            final horizontalPadding = isExtraWide
                ? 48.0
                : (isWide ? 32.0 : 20.0);

            return SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: horizontalPadding,
                vertical: 22,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ==================================
                  // HEADER: FULL WIDTH
                  // ==================================
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  'Hello, $displayName',
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.textMedium,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                const Text(
                                  '👋',
                                  style: TextStyle(fontSize: 16),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            ShaderMask(
                              shaderCallback: (bounds) => const LinearGradient(
                                colors: [
                                  AppTheme.darkBlue,
                                  AppTheme.primaryBlue,
                                  AppTheme.violet,
                                ],
                              ).createShader(bounds),
                              child: const Text(
                                'CareerPilot 🚀',
                                style: TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -0.6,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // NOTIFICATION BELL WITH LIVE UNREAD BADGE
                      StreamBuilder<int>(
                        stream: user != null
                            ? FirestoreService()
                                  .getUnreadNotificationsCountStream(user.uid)
                            : const Stream.empty(),
                        builder: (context, snapshot) {
                          final unread = snapshot.data ?? 0;
                          return Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Container(
                                width: 46,
                                height: 46,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: const Color(0xFFE2E8F0),
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(
                                        alpha: 0.04,
                                      ),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: IconButton(
                                  onPressed: _openNotifications,
                                  padding: EdgeInsets.zero,
                                  icon: const Icon(
                                    Icons.notifications_outlined,
                                    size: 24,
                                    color: AppTheme.darkBlue,
                                  ),
                                ),
                              ),
                              if (unread > 0)
                                Positioned(
                                  right: -2,
                                  top: -2,
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: const BoxDecoration(
                                      color: AppTheme.rose,
                                      shape: BoxShape.circle,
                                    ),
                                    constraints: const BoxConstraints(
                                      minWidth: 18,
                                      minHeight: 18,
                                    ),
                                    child: Center(
                                      child: Text(
                                        unread > 9 ? '9+' : '$unread',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          );
                        },
                      ),

                      const SizedBox(width: 10),

                      // PROFILE BUTTON
                      InkWell(
                        onTap: _openProfile,
                        borderRadius: BorderRadius.circular(30),
                        child: Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: AppTheme.primaryGradient,
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.primaryBlue.withValues(
                                  alpha: 0.35,
                                ),
                                blurRadius: 14,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(2.5),
                            child: CircleAvatar(
                              backgroundColor: Colors.white,
                              backgroundImage: user?.photoURL != null
                                  ? NetworkImage(user!.photoURL!)
                                  : null,
                              child: user?.photoURL == null
                                  ? const Icon(
                                      Icons.person_rounded,
                                      color: AppTheme.primaryBlue,
                                      size: 26,
                                    )
                                  : null,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 22),

                  // ==================================
                  // HERO BANNER (FULL WIDTH WITH VIBRANT GRADIENT)
                  // ==================================
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      gradient: AppTheme.heroGradient,
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primaryBlue.withValues(alpha: 0.35),
                          blurRadius: 28,
                          offset: const Offset(0, 12),
                        ),
                      ],
                    ),
                    child: Stack(
                      children: [
                        // Decorative glowing gradient bubbles
                        Positioned(
                          right: -20,
                          top: -20,
                          child: Container(
                            width: 180,
                            height: 180,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppTheme.violet.withValues(alpha: 0.25),
                            ),
                          ),
                        ),
                        Positioned(
                          right: 80,
                          bottom: -30,
                          child: Container(
                            width: 140,
                            height: 140,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppTheme.teal.withValues(alpha: 0.2),
                            ),
                          ),
                        ),

                        // Banner Content
                        Padding(
                          padding: EdgeInsets.all(isWide ? 32 : 24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.18),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.3),
                                  ),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.auto_awesome_rounded,
                                      color: Color(0xFFFDE68A),
                                      size: 15,
                                    ),
                                    SizedBox(width: 6),
                                    Text(
                                      'AI CAREER SUITE',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 0.6,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                'Build Your Tech Career With Confidence',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 28,
                                  fontWeight: FontWeight.w800,
                                  height: 1.2,
                                  letterSpacing: -0.5,
                                ),
                              ),
                              const SizedBox(height: 10),
                              const Text(
                                'Extract skills locally, get AI-driven ATS feedback, and discover verified career opportunities.',
                                style: TextStyle(
                                  color: Color(0xFFE2E8F0),
                                  fontSize: 14.5,
                                  height: 1.5,
                                ),
                              ),
                              const SizedBox(height: 22),

                              // Action Buttons in Hero
                              Wrap(
                                spacing: 12,
                                runSpacing: 10,
                                children: [
                                  ElevatedButton.icon(
                                    onPressed: _openResume,
                                    icon: const Icon(
                                      Icons.upload_file_rounded,
                                      size: 19,
                                    ),
                                    label: const Text('Upload Resume'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.white,
                                      foregroundColor: AppTheme.primaryBlue,
                                      elevation: 0,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 24,
                                        vertical: 14,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      textStyle: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  OutlinedButton.icon(
                                    onPressed: _openCareers,
                                    icon: const Icon(
                                      Icons.work_outline_rounded,
                                      size: 18,
                                      color: Colors.white,
                                    ),
                                    label: const Text(
                                      'Explore Careers',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                    style: OutlinedButton.styleFrom(
                                      side: const BorderSide(
                                        color: Colors.white70,
                                        width: 1.5,
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 20,
                                        vertical: 14,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 20),

                              // Quick Features Pill Row
                              Wrap(
                                spacing: 8,
                                runSpacing: 6,
                                children: const [
                                  _HeroFeaturePill(
                                    label: 'Gemini AI Analysis',
                                    icon: Icons.check_circle_outline_rounded,
                                  ),
                                  _HeroFeaturePill(
                                    label: 'Remotive Jobs',
                                    icon: Icons.check_circle_outline_rounded,
                                  ),
                                  _HeroFeaturePill(
                                    label: '100% Private & Local',
                                    icon: Icons.shield_outlined,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),

                  // ==================================
                  // CAREER TOOLS HEADER
                  // ==================================
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Career Tools',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.4,
                          color: AppTheme.textDark,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'AI & Job Hub',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.primaryBlue,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // ==================================
                  // FEATURE CARDS (RESPONSIVE GRID)
                  // ==================================
                  if (isWide) ...[
                    // WIDE SCREEN: 2-COLUMN GRID TO OCCUPY FULL WIDTH
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _buildVibrantFeatureCard(
                            icon: Icons.auto_awesome_rounded,
                            title: 'AI Resume Analysis',
                            badge: 'Gemini AI',
                            badgeColor: AppTheme.primaryBlue,
                            accentColor: AppTheme.primaryBlue,
                            backgroundGradient: const LinearGradient(
                              colors: [Colors.white, Color(0xFFEFF6FF)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            description:
                                'Local text extraction with Gemini analysis for score, strengths, and ATS readability.',
                            onTap: _openResume,
                          ),
                        ),
                        const SizedBox(width: 18),
                        Expanded(
                          child: _buildVibrantFeatureCard(
                            icon: Icons.work_history_rounded,
                            title: 'Career Opportunities',
                            badge: 'Live Jobs',
                            badgeColor: const Color(0xFF059669),
                            accentColor: const Color(0xFF059669),
                            backgroundGradient: const LinearGradient(
                              colors: [Colors.white, Color(0xFFECFDF5)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            description:
                                'Browse verified remote tech jobs with company details, locations, and instant applications.',
                            onTap: _openCareers,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _buildVibrantFeatureCard(
                            icon: Icons.alt_route_rounded,
                            title: 'Personalized Roadmap',
                            badge: 'Interactive',
                            badgeColor: AppTheme.violet,
                            accentColor: AppTheme.violet,
                            backgroundGradient: const LinearGradient(
                              colors: [Colors.white, Color(0xFFF5F3FF)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            description:
                                'Structured step-by-step career path with milestones, cloud sync, and skill development checkpoints.',
                            onTap: _openRoadmap,
                          ),
                        ),
                        const SizedBox(width: 18),
                        Expanded(
                          child: _buildVibrantFeatureCard(
                            icon: Icons.record_voice_over_rounded,
                            title: 'Mock Interviews',
                            badge: 'AI Simulator',
                            badgeColor: AppTheme.amber,
                            accentColor: AppTheme.amber,
                            backgroundGradient: const LinearGradient(
                              colors: [Colors.white, Color(0xFFFFFBEB)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            description:
                                'Interactive interview simulator with live AI evaluations, scoring rubrics, and detailed scorecards.',
                            onTap: _openMockInterviews,
                          ),
                        ),
                      ],
                    ),
                  ] else ...[
                    // MOBILE SCREEN: FULL-WIDTH VERTICAL LIST
                    _buildVibrantFeatureCard(
                      icon: Icons.auto_awesome_rounded,
                      title: 'AI Resume Analysis',
                      badge: 'Gemini AI',
                      badgeColor: AppTheme.primaryBlue,
                      accentColor: AppTheme.primaryBlue,
                      backgroundGradient: const LinearGradient(
                        colors: [Colors.white, Color(0xFFEFF6FF)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      description:
                          'Local text extraction with Gemini analysis for score, strengths, and ATS readability.',
                      onTap: _openResume,
                    ),
                    const SizedBox(height: 14),
                    _buildVibrantFeatureCard(
                      icon: Icons.work_history_rounded,
                      title: 'Career Opportunities',
                      badge: 'Live Jobs',
                      badgeColor: const Color(0xFF059669),
                      accentColor: const Color(0xFF059669),
                      backgroundGradient: const LinearGradient(
                        colors: [Colors.white, Color(0xFFECFDF5)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      description:
                          'Browse verified remote tech jobs with company details, locations, and instant applications.',
                      onTap: _openCareers,
                    ),
                    const SizedBox(height: 14),
                    _buildVibrantFeatureCard(
                      icon: Icons.alt_route_rounded,
                      title: 'Personalized Roadmap',
                      badge: 'Interactive',
                      badgeColor: AppTheme.violet,
                      accentColor: AppTheme.violet,
                      backgroundGradient: const LinearGradient(
                        colors: [Colors.white, Color(0xFFF5F3FF)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      description:
                          'Structured step-by-step career path with milestones, cloud sync, and skill development checkpoints.',
                      onTap: _openRoadmap,
                    ),
                    const SizedBox(height: 14),
                    _buildVibrantFeatureCard(
                      icon: Icons.record_voice_over_rounded,
                      title: 'Mock Interviews',
                      badge: 'AI Simulator',
                      badgeColor: AppTheme.amber,
                      accentColor: AppTheme.amber,
                      backgroundGradient: const LinearGradient(
                        colors: [Colors.white, Color(0xFFFFFBEB)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      description:
                          'Interactive interview simulator with live AI evaluations, scoring rubrics, and detailed scorecards.',
                      onTap: _openMockInterviews,
                    ),
                  ],

                  const SizedBox(height: 28),

                  // ==================================
                  // FULL-WIDTH SECURITY NOTICE CARD
                  // ==================================
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: AppTheme.primaryBlue.withValues(alpha: 0.18),
                      ),
                      boxShadow: AppTheme.softShadow,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.security_rounded,
                            color: AppTheme.primaryBlue,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 16),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Secure & Private by Design',
                                style: TextStyle(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.textDark,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Your resume contents are parsed locally in-memory and are never stored in public databases.',
                                style: TextStyle(
                                  color: AppTheme.textMedium,
                                  fontSize: 13,
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  // ==========================================
  // VIBRANT FEATURE CARD (FULL WIDTH & RICH COLOR)
  // ==========================================

  Widget _buildVibrantFeatureCard({
    required IconData icon,
    required String title,
    required String badge,
    required Color badgeColor,
    required Color accentColor,
    required LinearGradient backgroundGradient,
    required String description,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        gradient: backgroundGradient,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: accentColor.withValues(alpha: 0.28),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: accentColor.withValues(alpha: 0.08),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(22),
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Glowing Icon Badge
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [accentColor, accentColor.withValues(alpha: 0.8)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: accentColor.withValues(alpha: 0.35),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Icon(icon, color: Colors.white, size: 28),
                ),

                const SizedBox(width: 16),

                // Card Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textDark,
                                letterSpacing: -0.3,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 9,
                              vertical: 3.5,
                            ),
                            decoration: BoxDecoration(
                              color: badgeColor.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: badgeColor.withValues(alpha: 0.25),
                              ),
                            ),
                            child: Text(
                              badge,
                              style: TextStyle(
                                color: badgeColor,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        description,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppTheme.textMedium,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 10),

                // Arrow Circle
                Padding(
                  padding: const EdgeInsets.only(top: 14),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.arrow_forward_rounded,
                      size: 16,
                      color: accentColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HeroFeaturePill extends StatelessWidget {
  final String label;
  final IconData icon;

  const _HeroFeaturePill({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: const Color(0xFF6EE7B7), size: 14),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

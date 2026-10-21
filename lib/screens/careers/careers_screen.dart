import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../models/job_model.dart';
import '../../models/user_model.dart';
import '../../services/api_service.dart';
import '../../services/firestore_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/job_card.dart';
import '../roadmap/career_path_form_screen.dart';

class CareersScreen extends StatefulWidget {
  final String? initialSearchQuery;

  const CareersScreen({super.key, this.initialSearchQuery});

  @override
  State<CareersScreen> createState() => _CareersScreenState();
}

class _CareersScreenState extends State<CareersScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ApiService _apiService = ApiService();
  final FirestoreService _firestoreService = FirestoreService();
  final TextEditingController _searchController = TextEditingController();

  late Future<List<JobModel>> _jobsFuture;
  String _selectedCategory = 'All';
  String _activeSearchQuery = '';

  UserModel? _userProfile;

  // Remotive API categories
  final List<Map<String, String>> _categories = const [
    {'name': 'All', 'slug': ''},
    {'name': 'Software Dev', 'slug': 'software-dev'},
    {'name': 'Design', 'slug': 'design'},
    {'name': 'Data', 'slug': 'data'},
    {'name': 'DevOps', 'slug': 'devops-sysadmin'},
    {'name': 'Product', 'slug': 'product'},
    {'name': 'QA & Testing', 'slug': 'qa'},
    {'name': 'Customer Support', 'slug': 'customer-support'},
  ];

  User? get _currentUser => FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);

    if (widget.initialSearchQuery != null &&
        widget.initialSearchQuery!.isNotEmpty) {
      _activeSearchQuery = widget.initialSearchQuery!;
      _searchController.text = widget.initialSearchQuery!;
    }

    _jobsFuture = _fetchJobs();
    _loadUserProfile();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadUserProfile() async {
    final user = _currentUser;
    if (user != null) {
      try {
        final profile = await _firestoreService.getUserProfile(user.uid);
        if (mounted) {
          setState(() {
            _userProfile = profile;
          });
        }
      } catch (_) {}
    }
  }

  Future<List<JobModel>> _fetchJobs() {
    final catSlug =
        _categories.firstWhere(
          (c) => c['name'] == _selectedCategory,
          orElse: () => {'slug': ''},
        )['slug'] ??
        '';

    return _apiService.getJobs(
      search: _activeSearchQuery.isNotEmpty ? _activeSearchQuery : null,
      category: catSlug.isNotEmpty ? catSlug : null,
      limit: 50,
    );
  }

  void _triggerSearch() {
    setState(() {
      _activeSearchQuery = _searchController.text.trim();
      _jobsFuture = _fetchJobs();
    });
  }

  void _selectCategory(String categoryName) {
    if (_selectedCategory == categoryName) return;
    setState(() {
      _selectedCategory = categoryName;
      _jobsFuture = _fetchJobs();
    });
  }

  void _searchFromRole(String roleQuery) {
    _searchController.text = roleQuery;
    setState(() {
      _activeSearchQuery = roleQuery;
      _jobsFuture = _fetchJobs();
    });
    _tabController.animateTo(0);
  }

  Future<void> _handleToggleSaveJob(
    JobModel job,
    bool isCurrentlySaved,
    Set<String> savedJobIds,
  ) async {
    final user = _currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please log in to save jobs.'),
          backgroundColor: AppTheme.darkBlue,
        ),
      );
      return;
    }

    try {
      if (isCurrentlySaved) {
        await _firestoreService.removeSavedJob(user.uid, job.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Removed "${job.title}" from saved jobs.'),
              backgroundColor: AppTheme.darkBlue,
              action: SnackBarAction(
                label: 'UNDO',
                textColor: AppTheme.teal,
                onPressed: () => _firestoreService.saveJob(user.uid, job),
              ),
            ),
          );
        }
      } else {
        await _firestoreService.saveJob(user.uid, job);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Saved "${job.title}" to your bookmarks.'),
              backgroundColor: const Color(0xFF059669),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update bookmark: $e'),
            backgroundColor: AppTheme.rose,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = _currentUser?.uid ?? '';

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Career & Job Discovery',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppTheme.primaryBlue,
          unselectedLabelColor: AppTheme.textMedium,
          indicatorColor: AppTheme.primaryBlue,
          indicatorWeight: 3,
          labelStyle: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 13.5,
          ),
          tabs: const [
            Tab(icon: Icon(Icons.work_outline_rounded), text: 'Live Jobs'),
            Tab(icon: Icon(Icons.auto_awesome_outlined), text: 'Role Guidance'),
            Tab(icon: Icon(Icons.bookmark_outline_rounded), text: 'Saved Jobs'),
          ],
        ),
      ),
      body: StreamBuilder<List<JobModel>>(
        stream: uid.isNotEmpty
            ? _firestoreService.getSavedJobsStream(uid)
            : const Stream.empty(),
        builder: (context, savedSnapshot) {
          final savedJobs = savedSnapshot.data ?? [];
          final savedJobIds = savedJobs.map((j) => j.id).toSet();

          return TabBarView(
            controller: _tabController,
            children: [
              _buildLiveJobsTab(savedJobIds),
              _buildRoleGuidanceTab(),
              _buildSavedJobsTab(savedJobs, savedJobIds),
            ],
          );
        },
      ),
    );
  }

  // ============================================================
  // TAB 1: LIVE JOB BOARD
  // ============================================================

  Widget _buildLiveJobsTab(Set<String> savedJobIds) {
    return Column(
      children: [
        // Search & Filters Header
        Container(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            children: [
              // Search Input
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Search roles, skills, or companies...',
                        prefixIcon: const Icon(
                          Icons.search_rounded,
                          color: AppTheme.primaryBlue,
                        ),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 18),
                                onPressed: () {
                                  _searchController.clear();
                                  _triggerSearch();
                                },
                              )
                            : null,
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 12,
                          horizontal: 16,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(
                            color: Color(0xFFE2E8F0),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(
                            color: Color(0xFFE2E8F0),
                          ),
                        ),
                      ),
                      onSubmitted: (_) => _triggerSearch(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _triggerSearch,
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(50, 48),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text('Search'),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Categories Horizontal Scroll
              SizedBox(
                height: 38,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _categories.length,
                  itemBuilder: (context, index) {
                    final cat = _categories[index];
                    final name = cat['name']!;
                    final isSelected = _selectedCategory == name;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        label: Text(name),
                        selected: isSelected,
                        selectedColor: AppTheme.primaryBlue,
                        backgroundColor: const Color(0xFFF1F5F9),
                        checkmarkColor: Colors.white,
                        labelStyle: TextStyle(
                          fontSize: 12.5,
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.w500,
                          color: isSelected ? Colors.white : AppTheme.textDark,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        side: BorderSide(
                          color: isSelected
                              ? AppTheme.primaryBlue
                              : const Color(0xFFE2E8F0),
                        ),
                        onSelected: (_) => _selectCategory(name),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),

        // Live Jobs List
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async {
              setState(() {
                _jobsFuture = _fetchJobs();
              });
              await _jobsFuture;
            },
            child: FutureBuilder<List<JobModel>>(
              future: _jobsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text(
                          'Fetching live opportunities from Remotive API...',
                          style: TextStyle(
                            color: AppTheme.textMedium,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.cloud_off_rounded,
                            size: 56,
                            color: AppTheme.rose,
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Unable to load remote opportunities',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textDark,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${snapshot.error}'.replaceAll('Exception: ', ''),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: AppTheme.textMedium,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 20),
                          ElevatedButton.icon(
                            onPressed: () {
                              setState(() {
                                _jobsFuture = _fetchJobs();
                              });
                            },
                            icon: const Icon(Icons.refresh),
                            label: const Text('Try Again'),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                final jobs = snapshot.data ?? [];
                if (jobs.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.search_off_rounded,
                            size: 56,
                            color: Colors.grey,
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'No matching jobs found',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textDark,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Try broadening your keywords or selecting "All" categories.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: AppTheme.textMedium,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 20),
                          OutlinedButton(
                            onPressed: () {
                              _searchController.clear();
                              _selectCategory('All');
                            },
                            child: const Text('Reset All Filters'),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
                  itemCount: jobs.length + 1,
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Showing ${jobs.length} verified remote listings',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textMedium,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(
                                  0xFF059669,
                                ).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                'Remotive API',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF059669),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    final job = jobs[index - 1];
                    final isSaved = savedJobIds.contains(job.id);

                    return JobCard(
                      job: job,
                      isSaved: isSaved,
                      onToggleSave: () =>
                          _handleToggleSaveJob(job, isSaved, savedJobIds),
                    );
                  },
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // TAB 2: ROLE GUIDANCE & CAREER RECOMMENDATIONS
  // ============================================================

  Widget _buildRoleGuidanceTab() {
    final userGoal = _userProfile?.careerGoal.trim() ?? '';
    final recommendations = _getRoleRecommendations(userGoal);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppTheme.primaryBlue, AppTheme.violet],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primaryBlue.withValues(alpha: 0.28),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.insights_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      'AI Profile Recommendations',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  userGoal.isNotEmpty
                      ? 'Based on your selected profile target: "$userGoal"'
                      : 'Explore curated career directions matching modern tech industry hiring demands.',
                  style: const TextStyle(
                    color: Color(0xFFE2E8F0),
                    fontSize: 13.5,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),
          const Text(
            'Recommended Roles For You',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppTheme.textDark,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Tap "Search Jobs" to view open positions or "View Roadmap" to see the step-by-step path.',
            style: TextStyle(fontSize: 12.5, color: AppTheme.textMedium),
          ),
          const SizedBox(height: 16),

          ...recommendations.map(
            (rec) => _buildRoleRecommendationCard(
              title: rec['title'] as String,
              matchScore: rec['matchScore'] as String,
              description: rec['description'] as String,
              skills: (rec['skills'] as List<String>),
              searchKeyword: rec['searchKeyword'] as String,
              salaryRange: rec['salaryRange'] as String,
              experienceLevel: rec['experienceLevel'] as String,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoleRecommendationCard({
    required String title,
    required String matchScore,
    required String description,
    required List<String> skills,
    required String searchKeyword,
    required String salaryRange,
    required String experienceLevel,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
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
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textDark,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  matchScore,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryBlue,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: const TextStyle(
              fontSize: 13,
              color: AppTheme.textMedium,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppTheme.teal.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.signal_cellular_alt_rounded,
                      size: 13,
                      color: AppTheme.teal,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      experienceLevel,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.teal,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF059669).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.attach_money_rounded,
                      size: 13,
                      color: Color(0xFF059669),
                    ),
                    Text(
                      salaryRange,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF059669),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: skills.map((s) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  s,
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: AppTheme.textDark,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const CareerPathFormScreen(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.alt_route_rounded, size: 16),
                  label: const Text('View Roadmap'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    textStyle: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _searchFromRole(searchKeyword),
                  icon: const Icon(Icons.search, size: 16),
                  label: const Text('Search Jobs'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    textStyle: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<Map<String, dynamic>> _getRoleRecommendations(String userGoal) {
    final lower = userGoal.toLowerCase();

    if (lower.contains('flutter') || lower.contains('mobile')) {
      return [
        {
          'title': 'Flutter Application Developer',
          'matchScore': '98% Match',
          'description':
              'Design cross-platform apps using Dart, Flutter framework, state management, and Firebase backends.',
          'skills': ['Flutter', 'Dart', 'State Management', 'REST APIs', 'Git'],
          'searchKeyword': 'flutter',
          'salaryRange': '\$75k - \$130k',
          'experienceLevel': 'Entry to Mid',
        },
        {
          'title': 'Cross-Platform Mobile Engineer',
          'matchScore': '92% Match',
          'description':
              'Build robust native and hybrid mobile experiences across iOS and Android ecosystems.',
          'skills': [
            'Mobile Architecture',
            'CI/CD',
            'Offline Storage',
            'Firebase',
          ],
          'searchKeyword': 'mobile',
          'salaryRange': '\$85k - \$145k',
          'experienceLevel': 'Mid-Level',
        },
        {
          'title': 'Frontend Mobile & Web Engineer',
          'matchScore': '86% Match',
          'description':
              'Extend modern client applications to multi-device responsiveness with unified design systems.',
          'skills': ['TypeScript', 'Flutter Web', 'React', 'Responsive UI'],
          'searchKeyword': 'frontend',
          'salaryRange': '\$80k - \$135k',
          'experienceLevel': 'Mid-Level',
        },
      ];
    } else if (lower.contains('data') || lower.contains('scientist')) {
      return [
        {
          'title': 'Data Analyst',
          'matchScore': '96% Match',
          'description':
              'Extract insights, build interactive business intelligence dashboards, and query relational databases.',
          'skills': ['SQL', 'Python', 'Pandas', 'Power BI', 'Excel'],
          'searchKeyword': 'data analyst',
          'salaryRange': '\$65k - \$110k',
          'experienceLevel': 'Entry to Mid',
        },
        {
          'title': 'Data Scientist & ML Specialist',
          'matchScore': '90% Match',
          'description':
              'Formulate predictive models, statistical hypothesis tests, and data pipelines.',
          'skills': ['Python', 'Machine Learning', 'NumPy', 'Scikit-Learn'],
          'searchKeyword': 'data science',
          'salaryRange': '\$95k - \$160k',
          'experienceLevel': 'Mid to Senior',
        },
        {
          'title': 'Business Intelligence Developer',
          'matchScore': '85% Match',
          'description':
              'Translate executive requirements into strategic dashboards and data warehouses.',
          'skills': ['Tableau', 'DAX', 'SQL Data Warehouses', 'ETL Pipelines'],
          'searchKeyword': 'business intelligence',
          'salaryRange': '\$75k - \$125k',
          'experienceLevel': 'Mid-Level',
        },
      ];
    } else if (lower.contains('web')) {
      return [
        {
          'title': 'Frontend Web Developer',
          'matchScore': '97% Match',
          'description':
              'Craft responsive, accessible user interfaces with modern React, Next.js, and TypeScript.',
          'skills': [
            'React',
            'JavaScript (ES6+)',
            'Tailwind CSS',
            'HTML5/CSS3',
          ],
          'searchKeyword': 'frontend',
          'salaryRange': '\$70k - \$125k',
          'experienceLevel': 'Entry to Mid',
        },
        {
          'title': 'Full-Stack JavaScript Developer',
          'matchScore': '93% Match',
          'description':
              'Deliver complete client-server web apps with Node.js APIs, authentication, and SQL databases.',
          'skills': ['Node.js', 'Express', 'PostgreSQL', 'React', 'REST APIs'],
          'searchKeyword': 'fullstack',
          'salaryRange': '\$85k - \$145k',
          'experienceLevel': 'Mid-Level',
        },
      ];
    }

    // Default Tech Recommendations
    return [
      {
        'title': 'Software Engineer',
        'matchScore': '95% Match',
        'description':
            'Design scalable software architectures, algorithms, data structures, and modular backend services.',
        'skills': ['Data Structures', 'Algorithms', 'OOP', 'Git', 'Clean Code'],
        'searchKeyword': 'software',
        'salaryRange': '\$80k - \$140k',
        'experienceLevel': 'Entry to Mid',
      },
      {
        'title': 'Full-Stack Developer',
        'matchScore': '90% Match',
        'description':
            'End-to-end web and mobile system development, database modeling, and cloud deployments.',
        'skills': ['TypeScript', 'REST APIs', 'SQL', 'Docker', 'React'],
        'searchKeyword': 'developer',
        'salaryRange': '\$85k - \$145k',
        'experienceLevel': 'Mid-Level',
      },
      {
        'title': 'Mobile App Developer',
        'matchScore': '88% Match',
        'description':
            'Create delightful user experiences on iOS and Android with modern frameworks and cloud data.',
        'skills': ['Flutter', 'Mobile UI', 'Firebase', 'State Management'],
        'searchKeyword': 'mobile',
        'salaryRange': '\$75k - \$135k',
        'experienceLevel': 'Entry to Mid',
      },
    ];
  }

  // ============================================================
  // TAB 3: SAVED JOBS
  // ============================================================

  Widget _buildSavedJobsTab(List<JobModel> savedJobs, Set<String> savedJobIds) {
    if (_currentUser == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.lock_outline_rounded,
                size: 56,
                color: Colors.grey,
              ),
              const SizedBox(height: 16),
              const Text(
                'Sign In to Access Saved Jobs',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textDark,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Bookmarks are synchronized to your account so you can apply anytime.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppTheme.textMedium, fontSize: 13.5),
              ),
            ],
          ),
        ),
      );
    }

    if (savedJobs.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.bookmark_border_rounded,
                  size: 40,
                  color: AppTheme.primaryBlue,
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'No saved jobs yet',
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textDark,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Bookmark roles you are interested in while exploring the Live Jobs tab. They will appear here for easy tracking.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppTheme.textMedium,
                  fontSize: 13.5,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 22),
              ElevatedButton.icon(
                onPressed: () => _tabController.animateTo(0),
                icon: const Icon(Icons.explore_outlined),
                label: const Text('Browse Live Jobs'),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      itemCount: savedJobs.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${savedJobs.length} Bookmarked Opportunities',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textDark,
                  ),
                ),
                Text(
                  'Synced with Firestore',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          );
        }

        final job = savedJobs[index - 1];
        return JobCard(
          job: job,
          isSaved: true,
          onToggleSave: () => _handleToggleSaveJob(job, true, savedJobIds),
        );
      },
    );
  }
}

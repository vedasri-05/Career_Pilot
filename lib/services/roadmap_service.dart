import '../models/career_path_profile.dart';
import '../models/roadmap_model.dart';
import 'firestore_service.dart';

class RoadmapService {
  // In-memory singleton cache to retain roadmap state during the app session
  static CareerRoadmap? _currentRoadmap;
  static FirestoreService? _customFirestoreService;

  static FirestoreService get _firestoreService =>
      _customFirestoreService ?? FirestoreService();

  static void setFirestoreService(FirestoreService service) {
    _customFirestoreService = service;
  }

  static CareerRoadmap? get currentRoadmap => _currentRoadmap;

  static void setRoadmap(CareerRoadmap roadmap) {
    _currentRoadmap = roadmap;
  }

  static void clearRoadmap() {
    _currentRoadmap = null;
  }

  /// Loads the saved roadmap for [uid] from Firestore.
  static Future<CareerRoadmap?> loadUserRoadmap(String uid) async {
    try {
      final data = await _firestoreService.getSavedRoadmap(uid);
      if (data != null && data['stages'] != null) {
        final roadmap = CareerRoadmap.fromMap(data);
        _currentRoadmap = roadmap;
        return roadmap;
      }
    } catch (_) {
      // Return cached roadmap if Firestore is unavailable
    }
    return _currentRoadmap;
  }

  /// Saves the active [roadmap] for [uid] to Cloud Firestore.
  static Future<void> saveUserRoadmap(String uid, CareerRoadmap roadmap) async {
    _currentRoadmap = roadmap;
    try {
      await _firestoreService.saveRoadmap(uid, roadmap.toMap());
    } catch (_) {
      // Kept in memory even if offline
    }
  }

  /// Generates a rule-based roadmap customized to the user's profile.
  static CareerRoadmap generateRoadmap(CareerPathProfile profile) {
    final double hourMultiplier = _getHourMultiplier(profile.weeklyHours);
    final String role = profile.targetRole.trim();
    final List<String> userSkills = profile.skills
        .map((s) => s.toLowerCase().trim())
        .toList();
    final bool isAdvanced = profile.experienceLevel.toLowerCase().contains(
      'advanced',
    );
    final bool isIntermediate = profile.experienceLevel.toLowerCase().contains(
      'intermediate',
    );

    List<RoadmapStage> rawStages;

    final lowerRole = role.toLowerCase();
    if (lowerRole.contains('web')) {
      rawStages = _buildWebDeveloperStages();
    } else if (lowerRole.contains('data')) {
      rawStages = _buildDataAnalystStages();
    } else if (lowerRole.contains('software') ||
        lowerRole.contains('cloud') ||
        lowerRole.contains('devops') ||
        lowerRole.contains('security')) {
      rawStages = _buildSoftwareEngineerStages();
    } else {
      // Flutter / Mobile App Developer default
      rawStages = _buildFlutterDeveloperStages();
    }

    // Apply rule-based adaptations
    final List<RoadmapStage> customizedStages = [];

    for (final stage in rawStages) {
      int adjustedWeeks = (stage.estimatedWeeks * hourMultiplier).round();
      if (adjustedWeeks < 1) adjustedWeeks = 1;

      // Experience level adjustment
      if (stage.stageNumber == 1 && isAdvanced) {
        adjustedWeeks = (adjustedWeeks * 0.4).round().clamp(1, 10);
      } else if (stage.stageNumber == 1 && isIntermediate) {
        adjustedWeeks = (adjustedWeeks * 0.7).round().clamp(1, 10);
      }

      // Check skill matches for each topic
      for (final topic in stage.topics) {
        final matchesSkill = _matchesAnySkill(
          topic.title,
          topic.description,
          userSkills,
        );

        if (matchesSkill) {
          topic.isCompleted = true;
        } else if (stage.stageNumber == 1 && isAdvanced) {
          // Advanced users have already conquered stage 1 fundamentals
          topic.isCompleted = true;
        }
      }

      // Check skill matches for projects
      for (final project in stage.projects) {
        final matchesProject = project.technologies.any(
          (tech) => userSkills.contains(tech.toLowerCase().trim()),
        );
        if (matchesProject && (isAdvanced || isIntermediate)) {
          project.isCompleted = true;
        }
      }

      // Milestone auto-completion if all stage topics completed
      for (final milestone in stage.milestones) {
        if (stage.topics.isNotEmpty &&
            stage.topics.every((t) => t.isCompleted)) {
          milestone.isCompleted = true;
        }
      }

      customizedStages.add(
        RoadmapStage(
          stageNumber: stage.stageNumber,
          title: stage.title,
          description: stage.description,
          estimatedWeeks: adjustedWeeks,
          topics: stage.topics,
          projects: stage.projects,
          milestones: stage.milestones,
        ),
      );
    }

    final roadmap = CareerRoadmap(profile: profile, stages: customizedStages);

    _currentRoadmap = roadmap;
    return roadmap;
  }

  static double _getHourMultiplier(int weeklyHours) {
    if (weeklyHours >= 20) return 0.6;
    if (weeklyHours >= 15) return 0.8;
    if (weeklyHours >= 10) return 1.0;
    return 1.5; // <= 5 hours/week
  }

  static bool _matchesAnySkill(
    String title,
    String description,
    List<String> userSkills,
  ) {
    final combined = '$title $description'.toLowerCase();
    for (final skill in userSkills) {
      if (skill.length < 2) continue;
      if (combined.contains(skill)) {
        return true;
      }
    }
    return false;
  }

  // =========================================================================
  // FLUTTER DEVELOPER ROADMAP
  // =========================================================================
  static List<RoadmapStage> _buildFlutterDeveloperStages() {
    return [
      RoadmapStage(
        stageNumber: 1,
        title: 'Dart & Object-Oriented Fundamentals',
        description:
            'Master the core programming language powering Flutter applications.',
        estimatedWeeks: 3,
        topics: [
          RoadmapTopic(
            id: 'fl_d1',
            title: 'Dart Syntax & Type System',
            description:
                'Variables, final vs const, operators, and control flow statements.',
          ),
          RoadmapTopic(
            id: 'fl_d2',
            title: 'Object-Oriented Programming in Dart',
            description:
                'Classes, constructors, named parameters, inheritance, abstract classes, and mixins.',
          ),
          RoadmapTopic(
            id: 'fl_d3',
            title: 'Sound Null Safety',
            description:
                'Nullable types, assertion operator, late variables, and null-aware operators.',
          ),
          RoadmapTopic(
            id: 'fl_d4',
            title: 'Asynchronous Programming (Futures & Streams)',
            description:
                'async/await, Future API, Stream controllers, and error handling.',
          ),
          RoadmapTopic(
            id: 'fl_d5',
            title: 'Collections & Functional Methods',
            description:
                'Lists, Sets, Maps, spread operators, map, where, and fold functions.',
          ),
        ],
        projects: [
          RoadmapProject(
            id: 'fl_p1',
            title: 'CLI Task & Note Manager in Pure Dart',
            description:
                'Build a terminal application utilizing OOP, async file I/O, and JSON serialization.',
            technologies: ['Dart', 'OOP', 'JSON'],
          ),
        ],
        milestones: [
          RoadmapMilestone(
            id: 'fl_m1',
            title: 'Dart Language Proficiency',
            description:
                'Comfortable writing clean, sound, asynchronous Dart code.',
          ),
        ],
      ),
      RoadmapStage(
        stageNumber: 2,
        title: 'Flutter UI Engineering & Layouts',
        description:
            'Build responsive, pixel-perfect user interfaces across mobile and web.',
        estimatedWeeks: 4,
        topics: [
          RoadmapTopic(
            id: 'fl_ui1',
            title: 'Widget Architecture & Lifecycle',
            description:
                'Stateless vs Stateful widgets, widget tree, element tree, and render tree.',
          ),
          RoadmapTopic(
            id: 'fl_ui2',
            title: 'Material 3 Components & Theming',
            description:
                'AppTheme, color schemes, text themes, buttons, cards, and input styling.',
          ),
          RoadmapTopic(
            id: 'fl_ui3',
            title: 'Responsive & Adaptive Layouts',
            description:
                'Row, Column, Stack, Expanded, Flexible, LayoutBuilder, and MediaQuery.',
          ),
          RoadmapTopic(
            id: 'fl_ui4',
            title: 'Navigation & Routing',
            description:
                'Navigator 2.0, named routes, route arguments, and browser URL synchronization.',
          ),
          RoadmapTopic(
            id: 'fl_ui5',
            title: 'Forms & Input Validation',
            description:
                'TextEditingController, FormState validation, custom focus nodes, and input masks.',
          ),
        ],
        projects: [
          RoadmapProject(
            id: 'fl_p2',
            title: 'Responsive Recipe & E-Commerce Catalog App',
            description:
                'Create a multi-screen catalog with category filtering, responsive grid layouts, and detail views.',
            technologies: ['Flutter', 'Material 3', 'Responsive Design'],
          ),
        ],
        milestones: [
          RoadmapMilestone(
            id: 'fl_m2',
            title: 'Mobile & Web UI Mastery',
            description:
                'Able to implement any designer UI layout in Flutter with high fidelity.',
          ),
        ],
      ),
      RoadmapStage(
        stageNumber: 3,
        title: 'State Management & REST API Integration',
        description:
            'Architect scalable state flows and connect remote services.',
        estimatedWeeks: 4,
        topics: [
          RoadmapTopic(
            id: 'fl_sm1',
            title: 'Reactive State Management Patterns',
            description:
                'Deep dive into Provider, Riverpod, or BLoC / Cubit patterns.',
          ),
          RoadmapTopic(
            id: 'fl_sm2',
            title: 'HTTP Networking & REST APIs',
            description:
                'Connecting HTTP clients, parsing JSON payloads, handling status codes, and timeouts.',
          ),
          RoadmapTopic(
            id: 'fl_sm3',
            title: 'Local Storage & Offline Caching',
            description:
                'SharedPreferences, Hive / SQLite, and offline persistence strategy.',
          ),
          RoadmapTopic(
            id: 'fl_sm4',
            title: 'Error Handling & Retry Resilience',
            description:
                'Network retry interceptors, connectivity monitoring, and user-friendly snackbars/modals.',
          ),
        ],
        projects: [
          RoadmapProject(
            id: 'fl_p3',
            title: 'Real-Time News & Weather Application',
            description:
                'Build a production-grade app fetching remote APIs with caching, search, and reactive state.',
            technologies: ['Flutter', 'Provider/Riverpod', 'REST APIs', 'Hive'],
          ),
        ],
        milestones: [
          RoadmapMilestone(
            id: 'fl_m3',
            title: 'Data-Driven Flutter Architecture',
            description:
                'Successfully build apps driven by remote backend endpoints and state managers.',
          ),
        ],
      ),
      RoadmapStage(
        stageNumber: 4,
        title: 'Firebase, Clean Architecture & Advanced Features',
        description:
            'Enterprise architecture, cloud backends, and rich interactive animations.',
        estimatedWeeks: 4,
        topics: [
          RoadmapTopic(
            id: 'fl_arch1',
            title: 'Clean Architecture & Feature-First Structure',
            description:
                'Separation of concerns: Data layer, Domain layer, and Presentation layer.',
          ),
          RoadmapTopic(
            id: 'fl_arch2',
            title: 'Firebase Auth & Cloud Firestore Integration',
            description:
                'User authentication, session streams, Firestore CRUD, security rules, and queries.',
          ),
          RoadmapTopic(
            id: 'fl_arch3',
            title: 'Animations & Custom Painters',
            description:
                'Explicit animation controllers, Hero animations, animated builders, and Canvas painting.',
          ),
          RoadmapTopic(
            id: 'fl_arch4',
            title: 'Platform Channels & Device Features',
            description:
                'Camera, location, file storage, and method channels for native OS integration.',
          ),
        ],
        projects: [
          RoadmapProject(
            id: 'fl_p4',
            title: 'Full-Stack Community & Job Board App',
            description:
                'An end-to-end production application with authentication, real-time database, and notifications.',
            technologies: ['Flutter', 'Firebase', 'Clean Architecture'],
          ),
        ],
        milestones: [
          RoadmapMilestone(
            id: 'fl_m4',
            title: 'Full-Stack Mobile Engineer',
            description:
                'Capable of delivering commercial apps with cloud backends and clean architecture.',
          ),
        ],
      ),
      RoadmapStage(
        stageNumber: 5,
        title: 'Automated Testing, CI/CD & Store Deployment',
        description:
            'Test coverage, automated build pipelines, and production app releases.',
        estimatedWeeks: 3,
        topics: [
          RoadmapTopic(
            id: 'fl_ci1',
            title: 'Unit & Widget Testing with Mockito',
            description:
                'Writing comprehensive test suites for business logic and UI widget trees.',
          ),
          RoadmapTopic(
            id: 'fl_ci2',
            title: 'Static Analysis & Code Quality Checks',
            description:
                'flutter_lints configuration, custom analyzer rules, and code formatting hooks.',
          ),
          RoadmapTopic(
            id: 'fl_ci3',
            title: 'Continuous Integration with GitHub Actions',
            description:
                'Automating build verification, lint runs, test execution, and artifact generation.',
          ),
          RoadmapTopic(
            id: 'fl_ci4',
            title: 'App Store & Google Play Release Preparation',
            description:
                'App signing (Keystore, Provisioning Profile), splash screens, app icons, and privacy policies.',
          ),
        ],
        projects: [
          RoadmapProject(
            id: 'fl_p5',
            title: 'Production-Ready Open Source Portfolio App',
            description:
                'Deploy an open-source Flutter repository with >80% test coverage and automated CI/CD.',
            technologies: ['Flutter Test', 'GitHub Actions', 'Fastlane'],
          ),
        ],
        milestones: [
          RoadmapMilestone(
            id: 'fl_m5',
            title: 'Job-Ready Flutter Engineer',
            description:
                'Equipped with portfolio, testing proficiency, and deployment experience.',
          ),
        ],
      ),
    ];
  }

  // =========================================================================
  // WEB DEVELOPER ROADMAP
  // =========================================================================
  static List<RoadmapStage> _buildWebDeveloperStages() {
    return [
      RoadmapStage(
        stageNumber: 1,
        title: 'Semantic Web, CSS Layouts & Version Control',
        description:
            'The foundational pillars of web markup, modern CSS, and collaboration.',
        estimatedWeeks: 3,
        topics: [
          RoadmapTopic(
            id: 'wb_1',
            title: 'Semantic HTML5 & Accessibility (a11y)',
            description:
                'Document structure, ARIA roles, forms, metadata, and accessibility guidelines.',
          ),
          RoadmapTopic(
            id: 'wb_2',
            title: 'Modern CSS3 Layouts (Flexbox & Grid)',
            description:
                'Two-dimensional layouts, alignment, flex properties, and responsive design patterns.',
          ),
          RoadmapTopic(
            id: 'wb_3',
            title: 'Responsive Design & Mobile-First Strategy',
            description:
                'Media queries, relative units (rem, em, clamp), viewport meta, and fluid typography.',
          ),
          RoadmapTopic(
            id: 'wb_4',
            title: 'Git Version Control & GitHub',
            description:
                'Branching, commits, pull requests, resolving merge conflicts, and GitHub flow.',
          ),
        ],
        projects: [
          RoadmapProject(
            id: 'wb_p1',
            title: 'Responsive Agency & Developer Portfolio',
            description:
                'Build a high-performance, mobile-first portfolio website with clean semantic markup.',
            technologies: ['HTML5', 'CSS3', 'Flexbox', 'Grid', 'Git'],
          ),
        ],
        milestones: [
          RoadmapMilestone(
            id: 'wb_m1',
            title: 'Web Design Foundations',
            description:
                'Able to build fast, responsive, accessible web pages from design mockups.',
          ),
        ],
      ),
      RoadmapStage(
        stageNumber: 2,
        title: 'Modern JavaScript (ES6+) & DOM Engineering',
        description:
            'Programmatic control, event handling, and asynchronous browser APIs.',
        estimatedWeeks: 4,
        topics: [
          RoadmapTopic(
            id: 'wb_js1',
            title: 'JavaScript Core & Execution Context',
            description:
                'Scope, closures, hoisting, value vs reference, and the JavaScript Event Loop.',
          ),
          RoadmapTopic(
            id: 'wb_js2',
            title: 'ES6+ Features & Modern Syntax',
            description:
                'Arrow functions, destructuring, template literals, modules, and optional chaining.',
          ),
          RoadmapTopic(
            id: 'wb_js3',
            title: 'DOM Manipulation & Event Propagation',
            description:
                'Event bubbling, capturing, delegation, dynamic element creation, and form validation.',
          ),
          RoadmapTopic(
            id: 'wb_js4',
            title: 'Asynchronous JavaScript & Fetch API',
            description:
                'Promises, async/await, fetching JSON APIs, error handling, and browser storage.',
          ),
        ],
        projects: [
          RoadmapProject(
            id: 'wb_p2',
            title: 'Interactive Project Management Board (Kanban)',
            description:
                'Drag-and-drop task board with localStorage persistence, search filtering, and modal dialogs.',
            technologies: ['JavaScript', 'DOM APIs', 'LocalStorage'],
          ),
        ],
        milestones: [
          RoadmapMilestone(
            id: 'wb_m2',
            title: 'JavaScript Fluency',
            description:
                'Strong command of client-side logic and asynchronous browser programming.',
          ),
        ],
      ),
      RoadmapStage(
        stageNumber: 3,
        title: 'Frontend Framework (React / Next.js) & State',
        description:
            'Modern component architecture, reactive state, and single-page apps.',
        estimatedWeeks: 4,
        topics: [
          RoadmapTopic(
            id: 'wb_r1',
            title: 'Component Architecture & Props',
            description:
                'JSX syntax, functional components, unidirectional data flow, and conditional rendering.',
          ),
          RoadmapTopic(
            id: 'wb_r2',
            title: 'React Hooks Mastery',
            description:
                'useState, useEffect, useContext, useMemo, useCallback, and building custom hooks.',
          ),
          RoadmapTopic(
            id: 'wb_r3',
            title: 'Client-Side Routing & SPA Navigation',
            description:
                'React Router / Next.js app router, dynamic path parameters, query strings, and protected routes.',
          ),
          RoadmapTopic(
            id: 'wb_r4',
            title: 'Tailwind CSS & Component Libraries',
            description:
                'Utility-first styling, responsive prefixes, dark mode, and UI component integration.',
          ),
        ],
        projects: [
          RoadmapProject(
            id: 'wb_p3',
            title: 'Modern E-Commerce Storefront with Cart & Checkout',
            description:
                'Component-driven store with reactive shopping cart, filtering, search, and checkout simulator.',
            technologies: ['React', 'Next.js', 'Tailwind CSS', 'Context API'],
          ),
        ],
        milestones: [
          RoadmapMilestone(
            id: 'wb_m3',
            title: 'Modern Frontend Specialist',
            description:
                'Skilled in building modular, reactive web applications with React ecosystems.',
          ),
        ],
      ),
      RoadmapStage(
        stageNumber: 4,
        title: 'Backend APIs, Authentication & Databases',
        description:
            'Server-side architecture, RESTful web services, and database management.',
        estimatedWeeks: 4,
        topics: [
          RoadmapTopic(
            id: 'wb_be1',
            title: 'Node.js & Express Framework',
            description:
                'Server setup, routing, middleware pipeline, request parsing, and error handlers.',
          ),
          RoadmapTopic(
            id: 'wb_be2',
            title: 'RESTful API Standards & Validation',
            description:
                'HTTP methods, status codes, query pagination, and schema validation with Zod / Joi.',
          ),
          RoadmapTopic(
            id: 'wb_be3',
            title: 'Relational & Document Databases',
            description:
                'PostgreSQL / Supabase or MongoDB, database schemas, relationships, and queries.',
          ),
          RoadmapTopic(
            id: 'wb_be4',
            title: 'Authentication & Security Best Practices',
            description:
                'JWT tokens, secure HTTP-only cookies, password hashing (bcrypt), and CORS protection.',
          ),
        ],
        projects: [
          RoadmapProject(
            id: 'wb_p4',
            title: 'Full-Stack Developer Community Platform',
            description:
                'Full-stack platform with secure authentication, post feeds, comments, and database persistence.',
            technologies: ['Node.js', 'Express', 'PostgreSQL', 'React'],
          ),
        ],
        milestones: [
          RoadmapMilestone(
            id: 'wb_m4',
            title: 'Full-Stack Web Engineer',
            description:
                'Capable of delivering complete end-to-end web applications with secure backends.',
          ),
        ],
      ),
      RoadmapStage(
        stageNumber: 5,
        title: 'Testing, Cloud Deployment & Performance',
        description:
            'Testing frameworks, CI/CD pipelines, containerization, and cloud deployment.',
        estimatedWeeks: 3,
        topics: [
          RoadmapTopic(
            id: 'wb_dev1',
            title: 'Unit & Integration Testing (Vitest / RTL)',
            description:
                'Testing React components, API endpoints, mock HTTP handlers, and assertions.',
          ),
          RoadmapTopic(
            id: 'wb_dev2',
            title: 'Cloud Hosting & Serverless Functions',
            description:
                'Deployment on Vercel, Netlify, Render, environment variable management, and domains.',
          ),
          RoadmapTopic(
            id: 'wb_dev3',
            title: 'Web Performance & Core Web Vitals',
            description:
                'Lighthouse audits, code splitting, lazy loading, image optimization, and caching headers.',
          ),
          RoadmapTopic(
            id: 'wb_dev4',
            title: 'Containerization Basics with Docker',
            description:
                'Dockerfiles, container builds, port mappings, and multi-stage production builds.',
          ),
        ],
        projects: [
          RoadmapProject(
            id: 'wb_p5',
            title: 'Production Saas Web App with Automated CI/CD',
            description:
                'Deploy an automated web application with continuous integration and custom domain setup.',
            technologies: ['Docker', 'GitHub Actions', 'Vercel', 'Vitest'],
          ),
        ],
        milestones: [
          RoadmapMilestone(
            id: 'wb_m5',
            title: 'Job-Ready Web Developer',
            description:
                'Equipped with production portfolio, full-stack understanding, and deployment mastery.',
          ),
        ],
      ),
    ];
  }

  // =========================================================================
  // DATA ANALYST ROADMAP
  // =========================================================================
  static List<RoadmapStage> _buildDataAnalystStages() {
    return [
      RoadmapStage(
        stageNumber: 1,
        title: 'Spreadsheets, Data Modeling & Business KPIs',
        description:
            'Excel & Google Sheets advanced analytics, data cleaning, and metric tracking.',
        estimatedWeeks: 3,
        topics: [
          RoadmapTopic(
            id: 'da_1',
            title: 'Advanced Spreadsheet Functions',
            description:
                'XLOOKUP, INDEX/MATCH, nested IF statements, and conditional formatting.',
          ),
          RoadmapTopic(
            id: 'da_2',
            title: 'Data Cleaning & Transformation in Spreadsheets',
            description:
                'Text splitting, deduplication, handling missing values, and date transformations.',
          ),
          RoadmapTopic(
            id: 'da_3',
            title: 'Pivot Tables & Slicers',
            description:
                'Multi-dimensional summaries, calculated fields, and interactive slicer controls.',
          ),
          RoadmapTopic(
            id: 'da_4',
            title: 'Business Metrics & KPI Formulation',
            description:
                'Customer lifetime value (LTV), churn rates, conversion funnels, and ROI metrics.',
          ),
        ],
        projects: [
          RoadmapProject(
            id: 'da_p1',
            title: 'Executive Financial & Sales Performance Model',
            description:
                'Develop an automated spreadsheet model analyzing multi-regional sales and profit margins.',
            technologies: ['Advanced Excel', 'Pivot Tables', 'KPI Modeling'],
          ),
        ],
        milestones: [
          RoadmapMilestone(
            id: 'da_m1',
            title: 'Spreadsheet Analytics Specialist',
            description:
                'Competent in transforming unstructured spreadsheets into strategic dashboards.',
          ),
        ],
      ),
      RoadmapStage(
        stageNumber: 2,
        title: 'SQL & Relational Database Querying',
        description:
            'The core querying language for extracting, filtering, and joining enterprise data.',
        estimatedWeeks: 4,
        topics: [
          RoadmapTopic(
            id: 'da_sql1',
            title: 'SQL Fundamentals & Data Filtering',
            description:
                'SELECT, WHERE, ORDER BY, DISTINCT, operators, and pattern matching with LIKE.',
          ),
          RoadmapTopic(
            id: 'da_sql2',
            title: 'Relational Joins & Schema Relationships',
            description:
                'INNER, LEFT, RIGHT, and FULL joins across normalized relational tables.',
          ),
          RoadmapTopic(
            id: 'da_sql3',
            title: 'Aggregations & Grouping',
            description:
                'COUNT, SUM, AVG, MIN, MAX with GROUP BY and HAVING filters.',
          ),
          RoadmapTopic(
            id: 'da_sql4',
            title: 'Advanced SQL: Window Functions & CTEs',
            description:
                'ROW_NUMBER, RANK, DENSE_RANK, LEAD, LAG, and Common Table Expressions (WITH clauses).',
          ),
        ],
        projects: [
          RoadmapProject(
            id: 'da_p2',
            title: 'Customer Retention & Cohort Analysis SQL Pipeline',
            description:
                'Write modular SQL queries analyzing customer retention cohorts, revenue churn, and repeat purchases.',
            technologies: ['SQL', 'PostgreSQL', 'Window Functions', 'CTEs'],
          ),
        ],
        milestones: [
          RoadmapMilestone(
            id: 'da_m2',
            title: 'Database Querying Fluency',
            description:
                'Able to answer any business hypothesis using complex multi-table SQL queries.',
          ),
        ],
      ),
      RoadmapStage(
        stageNumber: 3,
        title: 'Python for Data Analysis (Pandas & NumPy)',
        description:
            'Automate data workflows, manipulation, and exploratory analysis in Python.',
        estimatedWeeks: 4,
        topics: [
          RoadmapTopic(
            id: 'da_py1',
            title: 'Python Core for Analysts',
            description:
                'Data types, lists, dictionaries, list comprehensions, and functional programming.',
          ),
          RoadmapTopic(
            id: 'da_py2',
            title: 'NumPy for Numerical Computation',
            description:
                'Vectorized operations, array indexing, mathematical operations, and broadcasting.',
          ),
          RoadmapTopic(
            id: 'da_py3',
            title: 'Pandas DataFrames & Data Wrangling',
            description:
                'Loading datasets (CSV/SQL), filtering, grouping, merging, and reshaping data.',
          ),
          RoadmapTopic(
            id: 'da_py4',
            title: 'Handling Missing Data & Outliers',
            description:
                'Imputation strategies, outlier detection (IQR, Z-scores), and data sanitization.',
          ),
        ],
        projects: [
          RoadmapProject(
            id: 'da_p3',
            title: 'Global Tech Job Market & Salary Trend EDA',
            description:
                'Jupyter notebook conducting comprehensive exploratory data analysis on modern salary datasets.',
            technologies: ['Python', 'Pandas', 'NumPy', 'Jupyter'],
          ),
        ],
        milestones: [
          RoadmapMilestone(
            id: 'da_m3',
            title: 'Data Wrangling Autonomy',
            description:
                'Able to ingest, clean, and analyze datasets programmatically in Python.',
          ),
        ],
      ),
      RoadmapStage(
        stageNumber: 4,
        title: 'Data Visualization & BI Dashboards (Power BI / Tableau)',
        description:
            'Visual storytelling, executive reporting, and business intelligence.',
        estimatedWeeks: 4,
        topics: [
          RoadmapTopic(
            id: 'da_bi1',
            title: 'Data Storytelling & Visual Encoding',
            description:
                'Selecting appropriate charts, decluttering visuals, and cognitive design principles.',
          ),
          RoadmapTopic(
            id: 'da_bi2',
            title: 'Python Visualizations with Matplotlib & Seaborn',
            description:
                'Distribution plots, heatmaps, box plots, scatter relationships, and chart styling.',
          ),
          RoadmapTopic(
            id: 'da_bi3',
            title: 'Power BI / Tableau Architecture',
            description:
                'Data import, star schema modeling, relationships, and calculated measures (DAX / calculated fields).',
          ),
          RoadmapTopic(
            id: 'da_bi4',
            title: 'Interactive Dashboards & Stakeholder Reports',
            description:
                'Designing interactive filters, cross-highlighting, drill-throughs, and executive summaries.',
          ),
        ],
        projects: [
          RoadmapProject(
            id: 'da_p4',
            title: 'Executive Business Intelligence Dashboard',
            description:
                'Interactive dashboard tracking corporate revenue, operational efficiency, and regional performance.',
            technologies: ['Power BI / Tableau', 'DAX', 'Visual Storytelling'],
          ),
        ],
        milestones: [
          RoadmapMilestone(
            id: 'da_m4',
            title: 'Business Intelligence Visualizer',
            description:
                'Translate technical analysis into executive business dashboards that drive decisions.',
          ),
        ],
      ),
      RoadmapStage(
        stageNumber: 5,
        title: 'Applied Statistics, A/B Testing & Portfolio Capstone',
        description:
            'Statistical inference, experimentation, and public analytical portfolio.',
        estimatedWeeks: 3,
        topics: [
          RoadmapTopic(
            id: 'da_stat1',
            title: 'Probability & Statistical Distributions',
            description:
                'Normal distribution, central limit theorem, standard deviation, and variance.',
          ),
          RoadmapTopic(
            id: 'da_stat2',
            title: 'Hypothesis Testing & A/B Experimentation',
            description:
                'Null hypothesis, p-values, significance levels, confidence intervals, and two-sample t-tests.',
          ),
          RoadmapTopic(
            id: 'da_stat3',
            title: 'Correlation vs. Causation Analysis',
            description:
                'Pearson/Spearman coefficients, confounding variables, and regression line interpretation.',
          ),
          RoadmapTopic(
            id: 'da_stat4',
            title: 'Portfolio & Technical Case Presentation',
            description:
                'Documenting findings with executive summaries, reproducible notebooks, and presentation decks.',
          ),
        ],
        projects: [
          RoadmapProject(
            id: 'da_p5',
            title: 'End-to-End Product A/B Testing Capstone Analysis',
            description:
                'Complete case study evaluating a marketing/feature A/B test with statistical conclusions and recommendations.',
            technologies: [
              'A/B Testing',
              'Python Statistics',
              'Portfolio Case Study',
            ],
          ),
        ],
        milestones: [
          RoadmapMilestone(
            id: 'da_m5',
            title: 'Job-Ready Data Analyst',
            description:
                'Ready with end-to-end data portfolio demonstrating SQL, Python, BI, and business acumen.',
          ),
        ],
      ),
    ];
  }

  // =========================================================================
  // SOFTWARE ENGINEER ROADMAP
  // =========================================================================
  static List<RoadmapStage> _buildSoftwareEngineerStages() {
    return [
      RoadmapStage(
        stageNumber: 1,
        title: 'Computer Science Foundations & Core Engineering',
        description:
            'Low-level systems knowledge, memory models, clean code, and environments.',
        estimatedWeeks: 3,
        topics: [
          RoadmapTopic(
            id: 'se_1',
            title: 'Programming Paradigms & Memory Models',
            description:
                'Procedural, object-oriented, and functional programming. Stack vs Heap memory allocation.',
          ),
          RoadmapTopic(
            id: 'se_2',
            title: 'Linux Shell & Developer Tooling',
            description:
                'Bash navigation, file permissions, pipes, process management, and Vim/IDE mastery.',
          ),
          RoadmapTopic(
            id: 'se_3',
            title: 'Clean Code & Refactoring Standards',
            description:
                'Descriptive naming, single responsibility functions, code smells, and DRY principles.',
          ),
          RoadmapTopic(
            id: 'se_4',
            title: 'Version Control with Advanced Git',
            description:
                'Interactive rebasing, cherry-picking, stash, bisect for bug hunting, and commit hygiene.',
          ),
        ],
        projects: [
          RoadmapProject(
            id: 'se_p1',
            title: 'Unix File System & Process Monitoring Utility',
            description:
                'Build a terminal utility that inspects memory usage, directory sizes, and file changes.',
            technologies: ['Core Language', 'POSIX APIs', 'Git'],
          ),
        ],
        milestones: [
          RoadmapMilestone(
            id: 'se_m1',
            title: 'Engineering Core Fundamentals',
            description:
                'Firm grasp of low-level concepts, command line environments, and clean code.',
          ),
        ],
      ),
      RoadmapStage(
        stageNumber: 2,
        title: 'Data Structures & Algorithmic Problem Solving',
        description:
            'Time & space complexity analysis and fundamental data structures.',
        estimatedWeeks: 5,
        topics: [
          RoadmapTopic(
            id: 'se_dsa1',
            title: 'Asymptotic Analysis & Big-O Notation',
            description:
                'Analyzing best, average, and worst-case time and space complexities.',
          ),
          RoadmapTopic(
            id: 'se_dsa2',
            title: 'Linear Data Structures',
            description:
                'Dynamic arrays, singly/doubly linked lists, stacks, queues, and ring buffers.',
          ),
          RoadmapTopic(
            id: 'se_dsa3',
            title: 'Hash Tables, Trees & Heaps',
            description:
                'Hash collisions, binary search trees (BST), balanced trees, and min/max priority heaps.',
          ),
          RoadmapTopic(
            id: 'se_dsa4',
            title: 'Graph Algorithms & Traversals',
            description:
                'Adjacency lists/matrices, Breadth-First Search (BFS), Depth-First Search (DFS), and Dijkstra.',
          ),
          RoadmapTopic(
            id: 'se_dsa5',
            title: 'Recursion, Two Pointers & Dynamic Programming',
            description:
                'Sliding window, binary search variations, memoization, and bottom-up DP arrays.',
          ),
        ],
        projects: [
          RoadmapProject(
            id: 'se_p2',
            title: 'Interactive Algorithm & Pathfinding Visualizer',
            description:
                'Application demonstrating step-by-step execution of sorting and graph pathfinding algorithms.',
            technologies: ['Algorithms', 'Data Structures', 'Visualization'],
          ),
        ],
        milestones: [
          RoadmapMilestone(
            id: 'se_m2',
            title: 'Algorithmic Competency',
            description:
                'Prepared to solve algorithmic challenges with optimal time and space tradeoffs.',
          ),
        ],
      ),
      RoadmapStage(
        stageNumber: 3,
        title: 'Object-Oriented Design & System Architecture',
        description:
            'Enterprise design patterns, SOLID engineering, and modular system decoupling.',
        estimatedWeeks: 4,
        topics: [
          RoadmapTopic(
            id: 'se_des1',
            title: 'SOLID Principles in Practice',
            description:
                'Single responsibility, open-closed, Liskov substitution, interface segregation, dependency inversion.',
          ),
          RoadmapTopic(
            id: 'se_des2',
            title: 'GoF Design Patterns',
            description:
                'Factory, Singleton, Builder, Adapter, Decorator, Observer, and Strategy patterns.',
          ),
          RoadmapTopic(
            id: 'se_des3',
            title: 'Monolithic vs. Microservice Architectures',
            description:
                'Trade-offs, service boundaries, database-per-service, and domain-driven design concepts.',
          ),
          RoadmapTopic(
            id: 'se_des4',
            title: 'API Protocols: REST, gRPC & WebSockets',
            description:
                'JSON over HTTP, protocol buffers with binary gRPC, and bidirectional streaming.',
          ),
        ],
        projects: [
          RoadmapProject(
            id: 'se_p3',
            title: 'Modular Multi-Tier E-Commerce / Banking Backend',
            description:
                'Construct a decoupled service applying SOLID principles and repository patterns.',
            technologies: ['Design Patterns', 'SOLID', 'Modular Architecture'],
          ),
        ],
        milestones: [
          RoadmapMilestone(
            id: 'se_m3',
            title: 'Software Design Architect',
            description:
                'Capable of designing scalable, maintainable, decoupled software systems.',
          ),
        ],
      ),
      RoadmapStage(
        stageNumber: 4,
        title: 'Databases, Caching & Distributed Systems',
        description:
            'Data storage guarantees, high throughput, caching, and concurrent systems.',
        estimatedWeeks: 4,
        topics: [
          RoadmapTopic(
            id: 'se_sys1',
            title: 'Database Internals: Indexing & Transactions',
            description:
                'B-Trees, WAL logs, ACID guarantees, isolation levels, and read/write replicas.',
          ),
          RoadmapTopic(
            id: 'se_sys2',
            title: 'Caching Strategies with Redis',
            description:
                'Cache-aside, write-through, TTL expiration, cache stampede prevention, and eviction policies.',
          ),
          RoadmapTopic(
            id: 'se_sys3',
            title: 'Concurrency, Multithreading & Race Conditions',
            description:
                'Threads, mutexes, locks, semaphores, deadlocks, and thread safety.',
          ),
          RoadmapTopic(
            id: 'se_sys4',
            title: 'Message Queues & Event-Driven Architecture',
            description:
                'Pub/sub messaging, message brokers (RabbitMQ/Kafka), and asynchronous background workers.',
          ),
        ],
        projects: [
          RoadmapProject(
            id: 'se_p4',
            title: 'High-Concurrency Rate Limiter & URL Shortener',
            description:
                'Distributed backend service featuring token bucket rate limiting, Redis caching, and database hashing.',
            technologies: [
              'Redis',
              'SQL',
              'Distributed Systems',
              'Rate Limiting',
            ],
          ),
        ],
        milestones: [
          RoadmapMilestone(
            id: 'se_m4',
            title: 'Distributed Systems Engineer',
            description:
                'Knowledgeable in designing fault-tolerant, high-concurrency systems.',
          ),
        ],
      ),
      RoadmapStage(
        stageNumber: 5,
        title: 'Testing, DevOps, Docker & Cloud Deployment',
        description:
            'Test automation, containerization, observability, and cloud deployments.',
        estimatedWeeks: 3,
        topics: [
          RoadmapTopic(
            id: 'se_ops1',
            title: 'Test-Driven Development (TDD) & Test Suites',
            description:
                'Unit tests, integration tests, mock objects, test coverage, and regression prevention.',
          ),
          RoadmapTopic(
            id: 'se_ops2',
            title: 'Containerization with Docker & Compose',
            description:
                'Multi-stage Dockerfiles, Docker networking, volume mounts, and docker-compose configurations.',
          ),
          RoadmapTopic(
            id: 'se_ops3',
            title: 'Automated CI/CD Pipelines',
            description:
                'GitHub Actions workflow automation for builds, tests, container publishing, and deploys.',
          ),
          RoadmapTopic(
            id: 'se_ops4',
            title: 'Observability: Metrics, Logging & Tracing',
            description:
                'Structured JSON logging, Prometheus metrics, distributed tracing, and health check endpoints.',
          ),
        ],
        projects: [
          RoadmapProject(
            id: 'se_p5',
            title: 'Containerized Cloud Microservice with Full CI/CD',
            description:
                'Deploy an observable, automated microservice with automated tests, Docker, and health monitoring.',
            technologies: ['Docker', 'CI/CD', 'TDD', 'Observability'],
          ),
        ],
        milestones: [
          RoadmapMilestone(
            id: 'se_m5',
            title: 'Job-Ready Software Engineer',
            description:
                'Armed with algorithmic skills, software architecture principles, and production DevOps skills.',
          ),
        ],
      ),
    ];
  }
}

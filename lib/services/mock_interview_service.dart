import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

import '../config/gemini_config.dart';
import '../models/mock_interview_model.dart';
import 'firestore_service.dart';

class MockInterviewService {
  final FirestoreService? _customFirestoreService;
  final http.Client? _customClient;

  MockInterviewService({
    FirestoreService? firestoreService,
    http.Client? client,
  }) : _customFirestoreService = firestoreService,
       _customClient = client;

  FirestoreService get _firestoreService =>
      _customFirestoreService ?? FirestoreService();

  // =========================================================================
  // QUESTION GENERATION (OFFLINE CURATED BANK + AI ENHANCED)
  // =========================================================================

  Future<List<MockInterviewQuestion>> getQuestions({
    required String role,
    required String difficulty,
    required String type,
    int count = 5,
  }) async {
    // 1. Gather matching questions from offline question bank
    final bank = _getCuratedQuestionsForRole(role, difficulty, type);

    // If count exceeds bank, or bank is small, cycle or shuffle
    bank.shuffle();
    final selected = bank.take(count).toList();

    if (selected.length < count) {
      // Pad with general technical or behavioral questions
      final general = _getGeneralQuestions(type, difficulty, role);
      general.shuffle();
      for (final q in general) {
        if (selected.length >= count) break;
        if (!selected.any((existing) => existing.id == q.id)) {
          selected.add(q);
        }
      }
    }

    return selected;
  }

  // =========================================================================
  // ANSWER EVALUATION (GEMINI AI WITH INTELLIGENT RULE-BASED FALLBACK)
  // =========================================================================

  Future<MockInterviewAnswer> evaluateAnswer({
    required MockInterviewQuestion question,
    required String userAnswer,
  }) async {
    final trimmedAnswer = userAnswer.trim();
    if (trimmedAnswer.isEmpty) {
      return MockInterviewAnswer(
        questionId: question.id,
        questionText: question.question,
        category: question.category,
        userAnswer: '(No answer provided)',
        score: 1,
        strengths: ['Attempted the interview session.'],
        improvements: [
          'Provide a detailed answer explaining your thought process and solution.',
        ],
        modelAnswer: question.sampleModelAnswer,
        answeredAt: DateTime.now(),
      );
    }

    // Try Gemini evaluation if API key is present
    if (GeminiConfig.hasApiKey) {
      try {
        final aiEvaluation = await _evaluateWithGemini(question, trimmedAnswer);
        if (aiEvaluation != null) {
          return aiEvaluation;
        }
      } catch (_) {
        // Fall back gracefully to rule-based rubric
      }
    }

    // Fallback to offline intelligent evaluation rubric
    return _evaluateWithLocalRubric(question, trimmedAnswer);
  }

  Future<MockInterviewAnswer?> _evaluateWithGemini(
    MockInterviewQuestion question,
    String userAnswer,
  ) async {
    final apiKey = GeminiConfig.apiKey;
    final endpoint = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/${GeminiConfig.modelName}:generateContent?key=$apiKey',
    );

    final prompt =
        '''
You are a senior hiring manager and tech interviewer evaluating a candidate for a ${question.role} (${question.difficulty} level) position.
Category: ${question.category}
Interview Question: "${question.question}"
Expected Key Concepts: ${question.expectedKeyPoints.join(', ')}

Candidate's Answer:
"""
$userAnswer
"""

Provide an honest, constructive technical assessment in valid JSON format:
{
  "score": <integer from 1 to 10 evaluating correctness, depth, communication, and clarity>,
  "strengths": [
    "<specific strong point in the candidate's explanation or approach>",
    "<another positive observation>"
  ],
  "improvements": [
    "<specific area where candidate could improve depth, missing concepts, or accuracy>",
    "<actionable suggestion for interview performance>"
  ],
  "modelAnswer": "<an exemplary 2-4 sentence model response demonstrating ideal structure and technical precision>"
}
''';

    final requestBody = jsonEncode({
      'contents': [
        {
          'parts': [
            {'text': prompt},
          ],
        },
      ],
      'generationConfig': {
        'responseMimeType': 'application/json',
        'temperature': 0.2,
      },
    });

    final client = _customClient ?? http.Client();
    try {
      final response = await client
          .post(
            endpoint,
            headers: {
              'Content-Type': 'application/json',
              'x-goog-api-key': apiKey,
            },
            body: requestBody,
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final candidates = data['candidates'] as List?;
        if (candidates != null && candidates.isNotEmpty) {
          final content = candidates.first['content'];
          final parts = content?['parts'] as List?;
          if (parts != null && parts.isNotEmpty) {
            String rawText = parts.first['text'] as String? ?? '';
            rawText = rawText.trim();
            if (rawText.startsWith('```json')) rawText = rawText.substring(7);
            if (rawText.startsWith('```')) rawText = rawText.substring(3);
            if (rawText.endsWith('```')) {
              rawText = rawText.substring(0, rawText.length - 3);
            }
            rawText = rawText.trim();

            final jsonMap = jsonDecode(rawText) as Map<String, dynamic>;
            final rawScore = (jsonMap['score'] as num?)?.toInt() ?? 7;
            final score = rawScore.clamp(1, 10);
            final strengths = List<String>.from(jsonMap['strengths'] ?? []);
            final improvements = List<String>.from(
              jsonMap['improvements'] ?? [],
            );
            final modelAnswer =
                jsonMap['modelAnswer'] as String? ?? question.sampleModelAnswer;

            return MockInterviewAnswer(
              questionId: question.id,
              questionText: question.question,
              category: question.category,
              userAnswer: userAnswer,
              score: score,
              strengths: strengths.isNotEmpty
                  ? strengths
                  : ['Addressed the main question.'],
              improvements: improvements.isNotEmpty
                  ? improvements
                  : ['Consider adding real-world examples.'],
              modelAnswer: modelAnswer.isNotEmpty
                  ? modelAnswer
                  : question.sampleModelAnswer,
              answeredAt: DateTime.now(),
            );
          }
        }
      }
    } finally {
      if (_customClient == null) {
        client.close();
      }
    }
    return null;
  }

  MockInterviewAnswer _evaluateWithLocalRubric(
    MockInterviewQuestion question,
    String userAnswer,
  ) {
    final lowerAnswer = userAnswer.toLowerCase();
    final words = userAnswer
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .length;

    // Count how many expected concepts were mentioned
    int matchedPoints = 0;
    final matchedList = <String>[];
    final missingList = <String>[];

    for (final point in question.expectedKeyPoints) {
      final pointWords = point
          .toLowerCase()
          .split(' ')
          .where((w) => w.length > 2);
      final hasMatch = pointWords.any((pw) => lowerAnswer.contains(pw));
      if (hasMatch) {
        matchedPoints++;
        matchedList.add(point);
      } else {
        missingList.add(point);
      }
    }

    // Scoring rubric: Base score from length and key concepts
    int calculatedScore = 5;
    if (words >= 40) calculatedScore += 1;
    if (words >= 80) calculatedScore += 1;

    if (question.expectedKeyPoints.isNotEmpty) {
      final matchRatio = matchedPoints / question.expectedKeyPoints.length;
      if (matchRatio >= 0.7) {
        calculatedScore += 2;
      } else if (matchRatio >= 0.4) {
        calculatedScore += 1;
      } else {
        calculatedScore -= 1;
      }
    }

    final finalScore = calculatedScore.clamp(2, 9);

    final strengths = <String>[];
    if (words >= 50) {
      strengths.add('Good answer length and comprehensive elaboration.');
    } else {
      strengths.add('Concise and direct response to the core topic.');
    }
    if (matchedList.isNotEmpty) {
      strengths.add(
        'Effectively addressed: ${matchedList.take(2).join(", ")}.',
      );
    } else {
      strengths.add('Articulated an understandable perspective.');
    }

    final improvements = <String>[];
    if (missingList.isNotEmpty) {
      improvements.add(
        'Could strengthen answer by mentioning: ${missingList.take(2).join(", ")}.',
      );
    }
    if (words < 40) {
      improvements.add(
        'Elaborate further with a concrete project example or trade-off analysis.',
      );
    } else {
      improvements.add(
        'Consider framing answers using the STAR method (Situation, Task, Action, Result) for added impact.',
      );
    }

    return MockInterviewAnswer(
      questionId: question.id,
      questionText: question.question,
      category: question.category,
      userAnswer: userAnswer,
      score: finalScore,
      strengths: strengths,
      improvements: improvements,
      modelAnswer: question.sampleModelAnswer,
      answeredAt: DateTime.now(),
    );
  }

  // =========================================================================
  // FIRESTORE PERSISTENCE
  // =========================================================================

  Future<void> saveSession(String uid, MockInterviewSession session) async {
    await _firestoreService.saveMockInterview(uid, session.id, session.toMap());
  }

  Stream<List<MockInterviewSession>> getSessionsStream(String uid) {
    return _firestoreService.getMockInterviewsStream(uid).map((list) {
      return list.map((item) => MockInterviewSession.fromMap(item)).toList();
    });
  }

  Future<List<MockInterviewSession>> getSessions(String uid) async {
    final list = await _firestoreService.getMockInterviews(uid);
    return list.map((item) => MockInterviewSession.fromMap(item)).toList();
  }

  // =========================================================================
  // CURATED QUESTION BANKS
  // =========================================================================

  List<MockInterviewQuestion> _getCuratedQuestionsForRole(
    String role,
    String difficulty,
    String type,
  ) {
    final lowerRole = role.toLowerCase();
    final List<MockInterviewQuestion> questions = [];

    // Add behavioral questions if type is Behavioral or Mixed
    if (type == 'Behavioral' || type == 'Mixed') {
      questions.addAll(_getBehavioralQuestions());
    }

    // Add technical questions if type is Technical or Mixed
    if (type == 'Technical' || type == 'Mixed') {
      if (lowerRole.contains('flutter') || lowerRole.contains('mobile')) {
        questions.addAll(_getFlutterQuestions(difficulty));
      } else if (lowerRole.contains('web')) {
        questions.addAll(_getWebQuestions(difficulty));
      } else if (lowerRole.contains('data')) {
        questions.addAll(_getDataQuestions(difficulty));
      } else {
        questions.addAll(_getSoftwareEngineerQuestions(difficulty));
      }
    }

    return questions;
  }

  List<MockInterviewQuestion> _getFlutterQuestions(String difficulty) {
    return [
      const MockInterviewQuestion(
        id: 'fl_q1',
        role: 'Flutter Developer',
        difficulty: 'Entry to Mid',
        category: 'Technical',
        question:
            'What is the fundamental difference between StatelessWidget and StatefulWidget in Flutter? When would you choose one over the other?',
        expectedKeyPoints: [
          'Immutable configuration vs mutable State object',
          'build method triggers',
          'setState() lifecycle',
          'Widget rebuilding performance',
        ],
        sampleModelAnswer:
            'A StatelessWidget is immutable and never changes its configuration once built, making it ideal for static displays, icons, and labels. A StatefulWidget pairs an immutable widget with a separate mutable State object that persists across rebuilds. We use StatefulWidget when the UI responds to user interaction, streams, timers, or network data via setState().',
      ),
      const MockInterviewQuestion(
        id: 'fl_q2',
        role: 'Flutter Developer',
        difficulty: 'Mid-Level',
        category: 'Technical',
        question:
            'Explain how BuildContext works in Flutter. Why do we see errors like "Looking up a deactivated widget\'s Ancestor"?',
        expectedKeyPoints: [
          'Element tree locator',
          'InheritedWidget lookup',
          'Asynchronous gaps & mounted check',
          'Navigator & Scaffold context resolution',
        ],
        sampleModelAnswer:
            'BuildContext is a handle to the location of a widget in the Element tree. It allows widgets to locate ancestors such as Theme, MediaQuery, or Navigator. The "deactivated ancestor" error occurs when an async operation (like awaiting an HTTP request) finishes after the widget has unmounted from the tree, so accessing context.mounted or holding onto outdated contexts triggers an exception.',
      ),
      const MockInterviewQuestion(
        id: 'fl_q3',
        role: 'Flutter Developer',
        difficulty: 'Mid to Senior',
        category: 'Technical',
        question:
            'Compare reactive state management approaches in Flutter (e.g., Provider/Riverpod vs BLoC/Cubit). What architectural trade-offs influence your choice?',
        expectedKeyPoints: [
          'Separation of UI and business logic',
          'Stream-based events vs ChangeNotifier',
          'Testability & boilerplate trade-offs',
          'Scalability in team codebases',
        ],
        sampleModelAnswer:
            'Provider and Riverpod offer lightweight, declarative dependency injection and reactive state with minimal boilerplate, well-suited for medium to large apps. BLoC enforces strict unidirectional data flow via Streams and distinct Events/States, which reduces ambiguity and makes enterprise workflows thoroughly testable at the cost of higher boilerplate.',
      ),
      const MockInterviewQuestion(
        id: 'fl_q4',
        role: 'Flutter Developer',
        difficulty: 'Mid-Level',
        category: 'Technical',
        question:
            'How does Flutter achieve 60/120 FPS rendering? What causes UI jank and how do you diagnose it with Flutter DevTools?',
        expectedKeyPoints: [
          'Impeller / Skia rendering engine',
          'Widget, Element, and Render trees',
          'Overbuilding widgets & const constructors',
          'DevTools CPU profiler and Performance overlay',
        ],
        sampleModelAnswer:
            'Flutter controls every pixel directly on the canvas without bridging to native OEM widgets. Jank occurs when a frame exceeds the 16.6ms budget, often due to expensive computations on the main UI isolate, unnecessary widget rebuilds, or shader compilation. We diagnose this in Flutter DevTools using the Performance view, CPU profiler, and track widget rebuild counts.',
      ),
      const MockInterviewQuestion(
        id: 'fl_q5',
        role: 'Flutter Developer',
        difficulty: 'Mid to Senior',
        category: 'System Design',
        question:
            'How would you architect offline data synchronization in a mobile Flutter application that connects to a REST API?',
        expectedKeyPoints: [
          'Local cache (Hive, SQLite, Isar)',
          'Sync queue for pending mutations',
          'Connectivity monitoring',
          'Conflict resolution strategy (timestamp or server-wins)',
        ],
        sampleModelAnswer:
            'I would implement a Repository pattern with a cache-first strategy. Reads load from SQLite/Hive immediately. Mutations are saved locally, tagged with an "isSynced: false" flag, and pushed to a synchronization worker queue. When connectivity restores, the queue submits changes to the REST API and resolves conflicts using optimistic concurrency timestamps.',
      ),
    ];
  }

  List<MockInterviewQuestion> _getWebQuestions(String difficulty) {
    return [
      const MockInterviewQuestion(
        id: 'wb_q1',
        role: 'Web Developer',
        difficulty: 'Entry to Mid',
        category: 'Technical',
        question:
            'Explain the JavaScript Event Loop, Call Stack, and Task Queues (Microtasks vs Macrotasks).',
        expectedKeyPoints: [
          'Single-threaded execution',
          'Call stack execution',
          'Promise microtasks priority over setTimeout macrotasks',
          'Non-blocking async I/O',
        ],
        sampleModelAnswer:
            'JavaScript has a single-threaded call stack. Asynchronous operations delegate to browser Web APIs. When complete, callbacks enter task queues: Microtasks (Promises, queueMicrotask) execute immediately after the current call stack clears, before any Macrotasks (setTimeout, setInterval, I/O) are picked up by the Event Loop.',
      ),
      const MockInterviewQuestion(
        id: 'wb_q2',
        role: 'Web Developer',
        difficulty: 'Mid-Level',
        category: 'Technical',
        question:
            'What is the Virtual DOM in React, and how does the reconciliation algorithm optimize rendering performance?',
        expectedKeyPoints: [
          'In-memory representation of DOM nodes',
          'Diffing algorithm heuristics',
          'Keys in lists for identity tracking',
          'Batching DOM updates',
        ],
        sampleModelAnswer:
            'The Virtual DOM is a lightweight JavaScript object representation of the real browser DOM. When component state changes, React creates a new VDOM tree, runs its diffing algorithm (Reconciliation) to find the minimum set of changes, and applies them in a single batch to the real DOM, avoiding expensive layout reflows.',
      ),
      const MockInterviewQuestion(
        id: 'wb_q3',
        role: 'Web Developer',
        difficulty: 'Mid to Senior',
        category: 'Technical',
        question:
            'Explain CORS (Cross-Origin Resource Sharing). How does the browser enforce it, and how do you resolve CORS errors on the server?',
        expectedKeyPoints: [
          'Same-Origin Policy (protocol, domain, port)',
          'Preflight OPTIONS request',
          'Access-Control-Allow-Origin header',
          'Security mitigation vs client proxy',
        ],
        sampleModelAnswer:
            'CORS is a browser security mechanism that restricts cross-origin HTTP requests. For complex requests (with custom headers or methods like PUT/DELETE), browsers send an OPTIONS preflight request. The server must reply with appropriate Access-Control-Allow-Origin, Allow-Methods, and Allow-Headers headers to grant permission.',
      ),
    ];
  }

  List<MockInterviewQuestion> _getDataQuestions(String difficulty) {
    return [
      const MockInterviewQuestion(
        id: 'da_q1',
        role: 'Data Analyst',
        difficulty: 'Entry to Mid',
        category: 'Technical',
        question:
            'What is the difference between INNER JOIN, LEFT JOIN, and FULL OUTER JOIN in SQL? Give a real-world business example of when to use each.',
        expectedKeyPoints: [
          'INNER JOIN matches records in both tables',
          'LEFT JOIN preserves all left table records with nulls',
          'FULL OUTER JOIN includes all unmatched records',
          'Customer vs Orders transaction example',
        ],
        sampleModelAnswer:
            'INNER JOIN returns only rows with matches in both tables (e.g. customers who have placed an order). LEFT JOIN retains all records from the primary table plus matched attributes from the secondary, useful for finding active customers alongside those with zero purchases. FULL OUTER JOIN captures all records regardless of match.',
      ),
      const MockInterviewQuestion(
        id: 'da_q2',
        role: 'Data Analyst',
        difficulty: 'Mid-Level',
        category: 'Technical',
        question:
            'Explain SQL Window Functions such as ROW_NUMBER(), RANK(), and DENSE_RANK(). When would you use a window function instead of a GROUP BY?',
        expectedKeyPoints: [
          'OVER (PARTITION BY ... ORDER BY ...)',
          'Preserving individual rows vs aggregation collapse',
          'Tie handling differences in ranking',
          'Top-N per category use case',
        ],
        sampleModelAnswer:
            'Unlike GROUP BY, which collapses multiple rows into a single summary row, Window Functions compute metrics across a partitioned subset while keeping individual row identities intact. ROW_NUMBER assigns sequential integers, RANK skips ranks upon ties, and DENSE_RANK assigns consecutive ranks without skipping.',
      ),
      const MockInterviewQuestion(
        id: 'da_q3',
        role: 'Data Analyst',
        difficulty: 'Mid to Senior',
        category: 'Problem Solving',
        question:
            'How do you design an A/B test for an e-commerce checkout flow? How do you determine sample size and statistical significance?',
        expectedKeyPoints: [
          'Hypothesis formulation & primary KPI (conversion rate)',
          'Sample size calculation via power analysis',
          'P-value, alpha (0.05), and beta/power (0.80)',
          'Avoiding peeking and sample ratio mismatch',
        ],
        sampleModelAnswer:
            'I define the null and alternative hypotheses focused on a primary metric like checkout conversion rate. I calculate minimum sample size beforehand using power analysis based on baseline conversion, minimum detectable effect, 95% confidence (alpha = 0.05), and 80% statistical power. I run the test without premature stopping and verify no sample ratio mismatch.',
      ),
    ];
  }

  List<MockInterviewQuestion> _getSoftwareEngineerQuestions(String difficulty) {
    return [
      const MockInterviewQuestion(
        id: 'se_q1',
        role: 'Software Engineer',
        difficulty: 'Mid-Level',
        category: 'Technical',
        question:
            'Explain how a Hash Table works internally. How are collisions handled, and what happens to time complexity during worst-case scenarios?',
        expectedKeyPoints: [
          'Hash function mapping keys to array indices',
          'Collision resolution (Chaining vs Open Addressing)',
          'Average O(1) vs worst-case O(n)',
          'Load factor and dynamic resizing',
        ],
        sampleModelAnswer:
            'A hash table uses a hash function to compute an index in an underlying bucket array. When two distinct keys hash to the same bucket, collisions are resolved via chaining (linked lists or balanced trees) or open addressing (linear/quadratic probing). Operations average O(1) time complexity, but degrade to O(n) if all keys collide into a single chain.',
      ),
      const MockInterviewQuestion(
        id: 'se_q2',
        role: 'Software Engineer',
        difficulty: 'Mid to Senior',
        category: 'System Design',
        question:
            'What are the core principles of SOLID object-oriented design? Pick one principle and describe how violating it leads to fragile code.',
        expectedKeyPoints: [
          'Single Responsibility, Open/Closed, Liskov, Interface Segregation, Dependency Inversion',
          'Open/Closed Principle (open for extension, closed for modification)',
          'Decoupling abstractions from concrete implementations',
        ],
        sampleModelAnswer:
            'SOLID represents Single Responsibility, Open/Closed, Liskov Substitution, Interface Segregation, and Dependency Inversion. For example, violating the Open/Closed Principle means modifying existing core classes with new switch/if statements every time a new payment provider is added, which risks breaking tested payment paths instead of extending an abstract interface.',
      ),
      const MockInterviewQuestion(
        id: 'se_q3',
        role: 'Software Engineer',
        difficulty: 'Mid to Senior',
        category: 'System Design',
        question:
            'How do you scale a database that receives 10x more reads than writes? What strategies and tradeoffs would you consider?',
        expectedKeyPoints: [
          'Read replicas with asynchronous replication',
          'In-memory caching with Redis/Memcached',
          'Database indexing on query patterns',
          'Eventual consistency tradeoffs',
        ],
        sampleModelAnswer:
            'For read-heavy workloads, I introduce an in-memory cache like Redis using a cache-aside pattern to eliminate redundant database queries. Next, I provision read replicas from the primary database to distribute query load. The tradeoff is accepting eventual consistency between writes to the primary and replication to secondary nodes.',
      ),
    ];
  }

  List<MockInterviewQuestion> _getBehavioralQuestions() {
    return [
      const MockInterviewQuestion(
        id: 'beh_q1',
        role: 'General Tech Candidate',
        difficulty: 'All Levels',
        category: 'Behavioral',
        question:
            'Tell me about a time when you faced a difficult technical bug or blocker under a tight deadline. How did you resolve it?',
        expectedKeyPoints: [
          'Situation & Task context',
          'Systematic debugging approach',
          'Communication with stakeholders',
          'Result and lesson learned',
        ],
        sampleModelAnswer:
            'During a pre-release launch, our authentication token refresh failed sporadically on poor networks. Using the STAR method: I communicated the risk early to my team lead, isolated the network race condition with unit tests and packet logs, implemented a mutex retry lock, and successfully deployed before launch without customer downtime.',
      ),
      const MockInterviewQuestion(
        id: 'beh_q2',
        role: 'General Tech Candidate',
        difficulty: 'All Levels',
        category: 'Behavioral',
        question:
            'Describe a situation where you disagreed with a colleague or lead regarding a technical decision or design choice. How did you handle it?',
        expectedKeyPoints: [
          'Focus on objective data and trade-offs rather than ego',
          'Active listening and seeking consensus',
          'Commitment once decision was finalized',
        ],
        sampleModelAnswer:
            'A teammate advocated for an unproven third-party library to speed up feature delivery, while I was concerned about long-term maintenance and library bloat. I scheduled a quick benchmarking session where we compared build size, licensing, and testability. We agreed on a smaller modular solution, and our collaboration remained strong.',
      ),
    ];
  }

  List<MockInterviewQuestion> _getGeneralQuestions(
    String type,
    String difficulty,
    String role,
  ) {
    return [
      MockInterviewQuestion(
        id: 'gen_q1',
        role: role,
        difficulty: difficulty,
        category: 'Problem Solving',
        question:
            'How do you approach learning and integrating a new framework, SDK, or language when joining a new codebase?',
        expectedKeyPoints: [
          'Reading official documentation & core guides',
          'Building small spike prototypes',
          'Inspecting existing patterns and test suites',
        ],
        sampleModelAnswer:
            'I review architectural diagrams and test suites first to understand expected behaviors. Then I build a small isolated proof-of-concept to understand lifecycle and errors, followed by pairing with teammates to align on conventions.',
      ),
      MockInterviewQuestion(
        id: 'gen_q2',
        role: role,
        difficulty: difficulty,
        category: 'Technical',
        question:
            'What code quality and testing practices do you follow to ensure your code is reliable, readable, and maintainable?',
        expectedKeyPoints: [
          'Automated unit & integration testing',
          'Static analysis & lint rules',
          'Descriptive naming & single responsibility',
          'Code review feedback',
        ],
        sampleModelAnswer:
            'I write automated unit tests for core logic, configure strict linter rules to maintain style consistency, adhere to single responsibility principles, and write comprehensive PR descriptions for transparent peer reviews.',
      ),
    ];
  }
}

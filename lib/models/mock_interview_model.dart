class MockInterviewQuestion {
  final String id;
  final String question;
  final String
  category; // 'Technical', 'Behavioral', 'System Design', 'Problem Solving'
  final List<String> expectedKeyPoints;
  final String difficulty; // 'Beginner', 'Mid-Level', 'Senior'
  final String role;
  final String sampleModelAnswer;

  const MockInterviewQuestion({
    required this.id,
    required this.question,
    required this.category,
    required this.expectedKeyPoints,
    required this.difficulty,
    required this.role,
    this.sampleModelAnswer = '',
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'question': question,
      'category': category,
      'expectedKeyPoints': expectedKeyPoints,
      'difficulty': difficulty,
      'role': role,
      'sampleModelAnswer': sampleModelAnswer,
    };
  }

  factory MockInterviewQuestion.fromMap(Map<String, dynamic> map) {
    return MockInterviewQuestion(
      id: map['id'] ?? '',
      question: map['question'] ?? '',
      category: map['category'] ?? 'Technical',
      expectedKeyPoints: List<String>.from(
        map['expectedKeyPoints'] ?? const [],
      ),
      difficulty: map['difficulty'] ?? 'Mid-Level',
      role: map['role'] ?? '',
      sampleModelAnswer: map['sampleModelAnswer'] ?? '',
    );
  }
}

class MockInterviewAnswer {
  final String questionId;
  final String questionText;
  final String category;
  final String userAnswer;
  final int score; // 1 to 10
  final List<String> strengths;
  final List<String> improvements;
  final String modelAnswer;
  final DateTime answeredAt;

  MockInterviewAnswer({
    required this.questionId,
    required this.questionText,
    required this.category,
    required this.userAnswer,
    required this.score,
    required this.strengths,
    required this.improvements,
    required this.modelAnswer,
    required this.answeredAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'questionId': questionId,
      'questionText': questionText,
      'category': category,
      'userAnswer': userAnswer,
      'score': score,
      'strengths': strengths,
      'improvements': improvements,
      'modelAnswer': modelAnswer,
      'answeredAt': answeredAt.toIso8601String(),
    };
  }

  factory MockInterviewAnswer.fromMap(Map<String, dynamic> map) {
    return MockInterviewAnswer(
      questionId: map['questionId'] ?? '',
      questionText: map['questionText'] ?? '',
      category: map['category'] ?? 'Technical',
      userAnswer: map['userAnswer'] ?? '',
      score: (map['score'] as num?)?.toInt() ?? 7,
      strengths: List<String>.from(map['strengths'] ?? const []),
      improvements: List<String>.from(map['improvements'] ?? const []),
      modelAnswer: map['modelAnswer'] ?? '',
      answeredAt: DateTime.tryParse(map['answeredAt'] ?? '') ?? DateTime.now(),
    );
  }
}

class MockInterviewSession {
  final String id;
  final String role;
  final String difficulty;
  final String type; // 'Technical', 'Behavioral', 'Mixed'
  final int totalQuestions;
  final int overallScore; // 0 to 100
  final DateTime completedAt;
  final List<MockInterviewAnswer> answers;
  final Map<String, double> categoryBreakdown;
  final List<String> recommendations;

  MockInterviewSession({
    required this.id,
    required this.role,
    required this.difficulty,
    required this.type,
    required this.totalQuestions,
    required this.overallScore,
    required this.completedAt,
    required this.answers,
    required this.categoryBreakdown,
    required this.recommendations,
  });

  String get performanceTier {
    if (overallScore >= 85) return 'Interview Ready (Advanced)';
    if (overallScore >= 70) return 'Proficient / Competitive';
    if (overallScore >= 55) return 'Promising (Needs Practice)';
    return 'Developing Core Skills';
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'role': role,
      'difficulty': difficulty,
      'type': type,
      'totalQuestions': totalQuestions,
      'overallScore': overallScore,
      'completedAt': completedAt.toIso8601String(),
      'answers': answers.map((a) => a.toMap()).toList(),
      'categoryBreakdown': categoryBreakdown,
      'recommendations': recommendations,
    };
  }

  factory MockInterviewSession.fromMap(Map<String, dynamic> map) {
    final answersList = (map['answers'] as List? ?? []);
    final rawBreakdown = Map<String, dynamic>.from(
      map['categoryBreakdown'] ?? const {},
    );
    final Map<String, double> parsedBreakdown = {};
    rawBreakdown.forEach((key, val) {
      parsedBreakdown[key] = (val as num).toDouble();
    });

    return MockInterviewSession(
      id: map['id'] ?? '',
      role: map['role'] ?? 'Software Developer',
      difficulty: map['difficulty'] ?? 'Mid-Level',
      type: map['type'] ?? 'Technical',
      totalQuestions:
          (map['totalQuestions'] as num?)?.toInt() ?? answersList.length,
      overallScore: (map['overallScore'] as num?)?.toInt() ?? 70,
      completedAt:
          DateTime.tryParse(map['completedAt'] ?? '') ?? DateTime.now(),
      answers: answersList
          .map((a) => MockInterviewAnswer.fromMap(Map<String, dynamic>.from(a)))
          .toList(),
      categoryBreakdown: parsedBreakdown,
      recommendations: List<String>.from(map['recommendations'] ?? const []),
    );
  }
}

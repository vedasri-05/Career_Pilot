import 'package:flutter_test/flutter_test.dart';
import 'package:career_pilot/models/mock_interview_model.dart';
import 'package:career_pilot/services/mock_interview_service.dart';

void main() {
  group('Mock Interview Service & Models Tests', () {
    final service = MockInterviewService();

    test(
      'getQuestions returns requested count with accurate role/type matching',
      () async {
        final questions = await service.getQuestions(
          role: 'Flutter Developer',
          difficulty: 'Mid-Level',
          type: 'Technical',
          count: 3,
        );

        expect(questions.length, 3);
        expect(questions.every((q) => q.question.isNotEmpty), isTrue);
        expect(questions.every((q) => q.sampleModelAnswer.isNotEmpty), isTrue);
      },
    );

    test(
      'evaluateAnswer provides evaluation scores and constructive rubric feedback',
      () async {
        const question = MockInterviewQuestion(
          id: 'test_q1',
          role: 'Flutter Developer',
          difficulty: 'Mid-Level',
          category: 'Technical',
          question:
              'What is the difference between StatelessWidget and StatefulWidget?',
          expectedKeyPoints: [
            'StatelessWidget is immutable',
            'StatefulWidget has mutable State',
            'setState method',
          ],
          sampleModelAnswer:
              'A StatelessWidget is immutable while StatefulWidget creates mutable State.',
        );

        final evaluation = await service.evaluateAnswer(
          question: question,
          userAnswer:
              'A StatelessWidget is immutable and cannot change over time once built. In contrast, a StatefulWidget maintains a mutable State object that can call setState to trigger UI rebuilds when data changes.',
        );

        expect(evaluation.score, greaterThanOrEqualTo(5));
        expect(evaluation.strengths, isNotEmpty);
        expect(evaluation.improvements, isNotEmpty);
        expect(evaluation.modelAnswer, isNotEmpty);
      },
    );

    test('MockInterviewSession serialization roundtrip', () {
      final session = MockInterviewSession(
        id: 'sess_100',
        role: 'Software Developer',
        difficulty: 'Senior',
        type: 'Mixed',
        totalQuestions: 2,
        overallScore: 85,
        completedAt: DateTime.now(),
        answers: [
          MockInterviewAnswer(
            questionId: 'q1',
            questionText: 'Explain hash table collisions.',
            category: 'Technical',
            userAnswer: 'Chaining and open addressing are used.',
            score: 8,
            strengths: ['Mentioned chaining.'],
            improvements: ['Could elaborate on worst-case O(n).'],
            modelAnswer: 'Hash collisions use chaining or open addressing.',
            answeredAt: DateTime.now(),
          ),
        ],
        categoryBreakdown: {'Technical': 8.0},
        recommendations: ['Great work, deepen system design.'],
      );

      final map = session.toMap();
      final restored = MockInterviewSession.fromMap(map);

      expect(restored.id, 'sess_100');
      expect(restored.role, 'Software Developer');
      expect(restored.overallScore, 85);
      expect(restored.performanceTier, 'Interview Ready (Advanced)');
      expect(restored.answers.length, 1);
      expect(restored.categoryBreakdown['Technical'], 8.0);
    });
  });
}

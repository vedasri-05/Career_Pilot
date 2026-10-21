import 'package:flutter_test/flutter_test.dart';
import 'package:career_pilot/models/user_model.dart';

void main() {
  group('Career Goal Configuration & UserModel Tests', () {
    test('contains all 13 specified career goal options in exact order', () {
      const expectedGoals = [
        'Software Developer',
        'Web Developer',
        'Mobile App Developer',
        'Data Analyst',
        'Data Scientist',
        'AI / Machine Learning Engineer',
        'Cybersecurity Specialist',
        'Cloud Engineer',
        'UI/UX Designer',
        'Product Manager',
        'Business Analyst',
        'DevOps Engineer',
        'Other',
      ];

      expect(UserModel.careerGoals, equals(expectedGoals));
      expect(UserModel.careerGoals.length, equals(13));
    });

    test(
      'UserModel serializes and deserializes standard career goal properly',
      () {
        final now = DateTime.now();
        final user = UserModel(
          uid: 'user_123',
          name: 'Jane Doe',
          email: 'jane@example.com',
          careerGoal: 'Mobile App Developer',
          profileImageUrl: 'https://example.com/pic.png',
          createdAt: now,
        );

        final map = user.toMap();
        expect(map['careerGoal'], equals('Mobile App Developer'));

        final reconstructed = UserModel.fromMap(map);
        expect(reconstructed.careerGoal, equals('Mobile App Developer'));
        expect(reconstructed.uid, equals('user_123'));
      },
    );

    test(
      'UserModel serializes and deserializes custom "Other" career goal properly',
      () {
        final now = DateTime.now();
        final user = UserModel(
          uid: 'user_456',
          name: 'Bob Smith',
          email: 'bob@example.com',
          careerGoal: 'Quantum Computing Specialist',
          createdAt: now,
        );

        final map = user.toMap();
        expect(map['careerGoal'], equals('Quantum Computing Specialist'));

        final reconstructed = UserModel.fromMap(map);
        expect(
          reconstructed.careerGoal,
          equals('Quantum Computing Specialist'),
        );
      },
    );

    test('UserModel handles missing or empty career goal gracefully', () {
      final emptyUser = UserModel.fromMap({
        'uid': 'user_789',
        'name': 'Sam',
        'email': 'sam@example.com',
      });

      expect(emptyUser.careerGoal, equals(''));
    });
  });
}

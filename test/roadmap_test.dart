import 'package:flutter_test/flutter_test.dart';
import 'package:career_pilot/models/career_path_profile.dart';
import 'package:career_pilot/models/roadmap_model.dart';
import 'package:career_pilot/services/roadmap_service.dart';

void main() {
  group('Personalized Career Roadmap Tests', () {
    test('generateRoadmap generates 5 stages for Flutter Developer', () {
      const profile = CareerPathProfile(
        targetRole: 'Flutter Developer',
        education: "Bachelor's Degree",
        skills: ['Dart'],
        experienceLevel: 'Beginner / Entry Level',
        weeklyHours: 10,
      );

      final roadmap = RoadmapService.generateRoadmap(profile);

      expect(roadmap.stages.length, 5);
      expect(roadmap.totalWeeks, greaterThan(0));
      expect(roadmap.totalItemsCount, greaterThan(10));
      // First stage Dart syntax should have auto-completed because 'Dart' is in user's skills
      expect(roadmap.completedItemsCount, greaterThan(0));
    });

    test(
      'generateRoadmap adapts stages for Data Analyst and Software Engineer',
      () {
        const daProfile = CareerPathProfile(
          targetRole: 'Data Analyst',
          education: "Bachelor's Degree",
          skills: ['SQL'],
          experienceLevel: 'Intermediate',
          weeklyHours: 15,
        );
        final daRoadmap = RoadmapService.generateRoadmap(daProfile);
        expect(
          daRoadmap.stages.first.title.toLowerCase(),
          contains('spreadsheet'),
        );

        const seProfile = CareerPathProfile(
          targetRole: 'Software Engineer',
          education: "Bachelor's Degree",
          skills: ['Git'],
          experienceLevel: 'Beginner / Entry Level',
          weeklyHours: 20,
        );
        final seRoadmap = RoadmapService.generateRoadmap(seProfile);
        expect(
          seRoadmap.stages.first.title.toLowerCase(),
          contains('computer science'),
        );
      },
    );

    test(
      'CareerRoadmap toMap and fromMap serialization roundtrip preserves state',
      () {
        const profile = CareerPathProfile(
          targetRole: 'Web Developer',
          education: "Bootcamp / Self-Taught",
          skills: ['HTML/CSS', 'JavaScript'],
          experienceLevel: 'Beginner / Entry Level',
          weeklyHours: 10,
        );

        final roadmap = RoadmapService.generateRoadmap(profile);
        final map = roadmap.toMap();
        final restored = CareerRoadmap.fromMap(map);

        expect(restored.profile.targetRole, 'Web Developer');
        expect(restored.stages.length, roadmap.stages.length);
        expect(restored.totalItemsCount, roadmap.totalItemsCount);
        expect(restored.completedItemsCount, roadmap.completedItemsCount);
        expect(restored.percentInt, roadmap.percentInt);
      },
    );
  });
}

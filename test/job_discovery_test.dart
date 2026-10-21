import 'package:flutter_test/flutter_test.dart';
import 'package:career_pilot/models/job_model.dart';
import 'package:career_pilot/services/api_service.dart';

void main() {
  group('Job Discovery & Model Tests', () {
    test('JobModel parses Remotive API JSON format correctly', () {
      final json = {
        'id': 12345,
        'url': 'https://remotive.com/job/12345',
        'title': 'Senior Flutter Engineer',
        'company_name': 'Acme Global',
        'company_logo': 'https://example.com/logo.png',
        'candidate_required_location': 'Worldwide',
        'job_type': 'full_time',
        'publication_date': '2026-10-20T10:00:00',
        'salary': '\$120,000 - \$140,000',
        'description': '<p>Join our <strong>mobile</strong> team!</p>',
        'tags': ['Flutter', 'Dart', 'Firebase'],
      };

      final job = JobModel.fromJson(json);

      expect(job.id, '12345');
      expect(job.title, 'Senior Flutter Engineer');
      expect(job.company, 'Acme Global');
      expect(job.companyLogo, 'https://example.com/logo.png');
      expect(job.location, 'Worldwide');
      expect(job.jobType, 'Full Time');
      expect(job.salary, '\$120,000 - \$140,000');
      expect(job.description, 'Join our mobile team!');
      expect(job.tags, containsAll(['Flutter', 'Dart', 'Firebase']));
    });

    test('JobModel serialization toMap and fromMap works symmetrically', () {
      final original = JobModel(
        id: 'job_99',
        title: 'Backend Engineer',
        company: 'Cloud Corp',
        companyLogo: 'https://cloud.com/logo.png',
        location: 'Remote, US',
        jobType: 'Full-time',
        publishedAt: '2026-10-21',
        salary: '\$130k',
        description: 'Design distributed microservices.',
        url: 'https://cloud.com/apply',
        tags: ['Go', 'Kubernetes'],
      );

      final map = original.toMap();
      final reconstructed = JobModel.fromMap(map);

      expect(reconstructed.id, original.id);
      expect(reconstructed.title, original.title);
      expect(reconstructed.company, original.company);
      expect(reconstructed.location, original.location);
      expect(reconstructed.salary, original.salary);
      expect(reconstructed.tags, original.tags);
    });

    test('ApiService.mapGoalToSearchQuery maps goals accurately', () {
      expect(ApiService.mapGoalToSearchQuery('Mobile App Developer'), 'mobile');
      expect(ApiService.mapGoalToSearchQuery('Web Developer'), 'frontend');
      expect(ApiService.mapGoalToSearchQuery('Data Analyst'), 'data analyst');
      expect(ApiService.mapGoalToSearchQuery('Software Developer'), 'software');
      expect(ApiService.mapGoalToSearchQuery('DevOps Engineer'), 'devops');
    });
  });
}

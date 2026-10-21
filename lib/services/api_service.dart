import 'dart:convert';
import 'package:http/http.dart' as http;

import '../models/job_model.dart';

class ApiService {
  static const String baseUrl = 'https://remotive.com/api/remote-jobs';

  final http.Client _client;

  ApiService({http.Client? client}) : _client = client ?? http.Client();

  /// Fetches live remote jobs from the Remotive API with optional search and category filters.
  Future<List<JobModel>> getJobs({
    String? search,
    String? category,
    int limit = 50,
  }) async {
    final queryParameters = <String, String>{};

    if (search != null && search.trim().isNotEmpty) {
      queryParameters['search'] = search.trim();
    }

    if (category != null && category.trim().isNotEmpty) {
      queryParameters['category'] = category.trim();
    }

    if (limit > 0) {
      queryParameters['limit'] = limit.toString();
    }

    final uri = Uri.parse(baseUrl).replace(queryParameters: queryParameters);

    try {
      final response = await _client
          .get(uri)
          .timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) {
        throw Exception(
          'Job discovery service returned status ${response.statusCode}',
        );
      }

      final Map<String, dynamic> data = jsonDecode(response.body);
      final List jobsJson = data['jobs'] as List? ?? [];

      return jobsJson.map((item) => JobModel.fromJson(item)).toList();
    } catch (e) {
      // Rethrow with clear message
      throw Exception('Could not fetch jobs: $e');
    }
  }

  /// Maps a candidate's target career goal to effective search queries.
  static String mapGoalToSearchQuery(String careerGoal) {
    final lower = careerGoal.toLowerCase().trim();
    if (lower.contains('flutter')) {
      return 'flutter';
    }
    if (lower.contains('mobile')) {
      return 'mobile';
    }
    if (lower.contains('web')) {
      return 'frontend';
    }
    if (lower.contains('data analyst')) {
      return 'data analyst';
    }
    if (lower.contains('data scientist')) {
      return 'data science';
    }
    if (lower.contains('machine learning') || lower.contains('ai')) {
      return 'machine learning';
    }
    if (lower.contains('cyber') || lower.contains('security')) {
      return 'security';
    }
    if (lower.contains('cloud')) {
      return 'cloud';
    }
    if (lower.contains('ui') ||
        lower.contains('ux') ||
        lower.contains('designer')) {
      return 'designer';
    }
    if (lower.contains('product manager')) {
      return 'product manager';
    }
    if (lower.contains('business analyst')) {
      return 'business analyst';
    }
    if (lower.contains('devops')) {
      return 'devops';
    }
    if (lower.contains('software')) {
      return 'software';
    }
    return lower.isNotEmpty ? lower : 'developer';
  }
}

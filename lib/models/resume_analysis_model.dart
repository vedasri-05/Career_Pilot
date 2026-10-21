class ResumeAnalysisModel {
  final int score;
  final List<String> strengths;
  final List<String> weaknesses;
  final List<String> demonstratedSkills;
  final List<String> missingSkills;
  final String atsFeedback;
  final List<String> improvementSuggestions;

  const ResumeAnalysisModel({
    required this.score,
    required this.strengths,
    required this.weaknesses,
    required this.demonstratedSkills,
    required this.missingSkills,
    required this.atsFeedback,
    required this.improvementSuggestions,
  });

  factory ResumeAnalysisModel.fromJson(Map<String, dynamic> json) {
    int parsedScore = 0;
    final rawScore = json['score'];
    if (rawScore is num) {
      parsedScore = rawScore.clamp(0, 100).toInt();
    } else if (rawScore is String) {
      final parsed = int.tryParse(rawScore);
      if (parsed != null) {
        parsedScore = parsed.clamp(0, 100);
      }
    }

    List<String> parseList(dynamic rawList) {
      if (rawList is List) {
        return rawList
            .map((item) => item?.toString().trim() ?? '')
            .where((item) => item.isNotEmpty)
            .toList();
      }
      return <String>[];
    }

    return ResumeAnalysisModel(
      score: parsedScore,
      strengths: parseList(json['strengths']),
      weaknesses: parseList(json['weaknesses']),
      demonstratedSkills: parseList(json['demonstratedSkills']),
      missingSkills: parseList(json['missingSkills']),
      atsFeedback:
          (json['atsFeedback'] as String?)?.trim() ??
          'No specific ATS feedback provided.',
      improvementSuggestions: parseList(json['improvementSuggestions']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'score': score,
      'strengths': strengths,
      'weaknesses': weaknesses,
      'demonstratedSkills': demonstratedSkills,
      'missingSkills': missingSkills,
      'atsFeedback': atsFeedback,
      'improvementSuggestions': improvementSuggestions,
    };
  }
}

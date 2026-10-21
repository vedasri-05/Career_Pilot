class CareerPathProfile {
  final String targetRole;
  final String education;
  final List<String> skills;
  final String experienceLevel;
  final int weeklyHours;

  const CareerPathProfile({
    required this.targetRole,
    required this.education,
    required this.skills,
    required this.experienceLevel,
    required this.weeklyHours,
  });

  Map<String, dynamic> toMap() {
    return {
      'targetRole': targetRole,
      'education': education,
      'skills': skills,
      'experienceLevel': experienceLevel,
      'weeklyHours': weeklyHours,
    };
  }

  factory CareerPathProfile.fromMap(Map<String, dynamic> map) {
    return CareerPathProfile(
      targetRole: map['targetRole'] ?? 'Flutter Developer',
      education: map['education'] ?? "Bachelor's Degree",
      skills: List<String>.from(map['skills'] ?? const []),
      experienceLevel: map['experienceLevel'] ?? 'Beginner / Entry Level',
      weeklyHours: (map['weeklyHours'] as num?)?.toInt() ?? 10,
    );
  }

  CareerPathProfile copyWith({
    String? targetRole,
    String? education,
    List<String>? skills,
    String? experienceLevel,
    int? weeklyHours,
  }) {
    return CareerPathProfile(
      targetRole: targetRole ?? this.targetRole,
      education: education ?? this.education,
      skills: skills ?? this.skills,
      experienceLevel: experienceLevel ?? this.experienceLevel,
      weeklyHours: weeklyHours ?? this.weeklyHours,
    );
  }
}

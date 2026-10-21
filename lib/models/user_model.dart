class UserModel {
  static const List<String> careerGoals = [
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

  final String uid;
  final String name;
  final String email;
  final String careerGoal;
  final String profileImageUrl;
  final DateTime createdAt;

  UserModel({
    required this.uid,
    required this.name,
    required this.email,
    required this.careerGoal,
    this.profileImageUrl = '',
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'name': name,
      'email': email,
      'careerGoal': careerGoal,
      'profileImageUrl': profileImageUrl,
      'photoUrl': profileImageUrl,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      uid: map['uid'] ?? '',
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      careerGoal: map['careerGoal'] ?? '',
      profileImageUrl:
          map['profileImageUrl'] ?? map['photoUrl'] ?? map['photoBase64'] ?? '',
      createdAt: DateTime.tryParse(map['createdAt'] ?? '') ?? DateTime.now(),
    );
  }

  UserModel copyWith({
    String? uid,
    String? name,
    String? email,
    String? careerGoal,
    String? profileImageUrl,
    DateTime? createdAt,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      name: name ?? this.name,
      email: email ?? this.email,
      careerGoal: careerGoal ?? this.careerGoal,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

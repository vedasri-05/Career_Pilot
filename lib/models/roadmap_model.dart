import 'career_path_profile.dart';

class RoadmapTopic {
  final String id;
  final String title;
  final String description;
  bool isCompleted;
  final bool isAlreadyKnown;

  RoadmapTopic({
    required this.id,
    required this.title,
    required this.description,
    this.isCompleted = false,
    this.isAlreadyKnown = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'isCompleted': isCompleted,
      'isAlreadyKnown': isAlreadyKnown,
    };
  }

  factory RoadmapTopic.fromMap(Map<String, dynamic> map) {
    return RoadmapTopic(
      id: map['id'] ?? '',
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      isCompleted: map['isCompleted'] ?? false,
      isAlreadyKnown: map['isAlreadyKnown'] ?? false,
    );
  }
}

class RoadmapProject {
  final String id;
  final String title;
  final String description;
  final List<String> technologies;
  bool isCompleted;

  RoadmapProject({
    required this.id,
    required this.title,
    required this.description,
    required this.technologies,
    this.isCompleted = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'technologies': technologies,
      'isCompleted': isCompleted,
    };
  }

  factory RoadmapProject.fromMap(Map<String, dynamic> map) {
    return RoadmapProject(
      id: map['id'] ?? '',
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      technologies: List<String>.from(map['technologies'] ?? const []),
      isCompleted: map['isCompleted'] ?? false,
    );
  }
}

class RoadmapMilestone {
  final String id;
  final String title;
  final String description;
  bool isCompleted;

  RoadmapMilestone({
    required this.id,
    required this.title,
    required this.description,
    this.isCompleted = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'isCompleted': isCompleted,
    };
  }

  factory RoadmapMilestone.fromMap(Map<String, dynamic> map) {
    return RoadmapMilestone(
      id: map['id'] ?? '',
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      isCompleted: map['isCompleted'] ?? false,
    );
  }
}

class RoadmapStage {
  final int stageNumber;
  final String title;
  final String description;
  final int estimatedWeeks;
  final List<RoadmapTopic> topics;
  final List<RoadmapProject> projects;
  final List<RoadmapMilestone> milestones;

  RoadmapStage({
    required this.stageNumber,
    required this.title,
    required this.description,
    required this.estimatedWeeks,
    required this.topics,
    required this.projects,
    required this.milestones,
  });

  int get totalItemsCount =>
      topics.length + projects.length + milestones.length;

  int get completedItemsCount =>
      topics.where((t) => t.isCompleted).length +
      projects.where((p) => p.isCompleted).length +
      milestones.where((m) => m.isCompleted).length;

  double get progress =>
      totalItemsCount == 0 ? 0.0 : completedItemsCount / totalItemsCount;

  bool get isCompleted =>
      totalItemsCount > 0 && completedItemsCount == totalItemsCount;

  Map<String, dynamic> toMap() {
    return {
      'stageNumber': stageNumber,
      'title': title,
      'description': description,
      'estimatedWeeks': estimatedWeeks,
      'topics': topics.map((t) => t.toMap()).toList(),
      'projects': projects.map((p) => p.toMap()).toList(),
      'milestones': milestones.map((m) => m.toMap()).toList(),
    };
  }

  factory RoadmapStage.fromMap(Map<String, dynamic> map) {
    return RoadmapStage(
      stageNumber: (map['stageNumber'] as num?)?.toInt() ?? 1,
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      estimatedWeeks: (map['estimatedWeeks'] as num?)?.toInt() ?? 2,
      topics: (map['topics'] as List? ?? [])
          .map((t) => RoadmapTopic.fromMap(Map<String, dynamic>.from(t)))
          .toList(),
      projects: (map['projects'] as List? ?? [])
          .map((p) => RoadmapProject.fromMap(Map<String, dynamic>.from(p)))
          .toList(),
      milestones: (map['milestones'] as List? ?? [])
          .map((m) => RoadmapMilestone.fromMap(Map<String, dynamic>.from(m)))
          .toList(),
    );
  }
}

class CareerRoadmap {
  final CareerPathProfile profile;
  final List<RoadmapStage> stages;

  CareerRoadmap({required this.profile, required this.stages});

  int get totalWeeks =>
      stages.fold<int>(0, (sum, stage) => sum + stage.estimatedWeeks);

  int get totalItemsCount =>
      stages.fold<int>(0, (sum, stage) => sum + stage.totalItemsCount);

  int get completedItemsCount =>
      stages.fold<int>(0, (sum, stage) => sum + stage.completedItemsCount);

  double get progressPercentage =>
      totalItemsCount == 0 ? 0.0 : completedItemsCount / totalItemsCount;

  int get percentInt => (progressPercentage * 100).round();

  Map<String, dynamic> toMap() {
    return {
      'profile': profile.toMap(),
      'stages': stages.map((s) => s.toMap()).toList(),
      'totalWeeks': totalWeeks,
      'completedItemsCount': completedItemsCount,
      'totalItemsCount': totalItemsCount,
      'progressPercentage': progressPercentage,
    };
  }

  factory CareerRoadmap.fromMap(Map<String, dynamic> map) {
    final profileMap = Map<String, dynamic>.from(map['profile'] ?? const {});
    final stagesList = (map['stages'] as List? ?? []);

    return CareerRoadmap(
      profile: CareerPathProfile.fromMap(profileMap),
      stages: stagesList
          .map((s) => RoadmapStage.fromMap(Map<String, dynamic>.from(s)))
          .toList(),
    );
  }
}

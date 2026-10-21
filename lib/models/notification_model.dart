enum NotificationType {
  roadmapReminder,
  roadmapMilestone,
  jobAlert,
  interviewScorecard,
  careerReminder,
  general;

  String toValue() {
    switch (this) {
      case NotificationType.roadmapReminder:
        return 'roadmapReminder';
      case NotificationType.roadmapMilestone:
        return 'roadmapMilestone';
      case NotificationType.jobAlert:
        return 'jobAlert';
      case NotificationType.interviewScorecard:
        return 'interviewScorecard';
      case NotificationType.careerReminder:
        return 'careerReminder';
      case NotificationType.general:
        return 'general';
    }
  }

  static NotificationType fromValue(String? value) {
    switch (value) {
      case 'roadmapReminder':
        return NotificationType.roadmapReminder;
      case 'roadmapMilestone':
        return NotificationType.roadmapMilestone;
      case 'jobAlert':
        return NotificationType.jobAlert;
      case 'interviewScorecard':
        return NotificationType.interviewScorecard;
      case 'careerReminder':
        return NotificationType.careerReminder;
      case 'general':
      default:
        return NotificationType.general;
    }
  }
}

class AppNotification {
  final String id;
  final String title;
  final String body;
  final NotificationType type;
  final Map<String, dynamic> data;
  final DateTime createdAt;
  bool isRead;

  AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    this.data = const {},
    required this.createdAt,
    this.isRead = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'body': body,
      'type': type.toValue(),
      'data': data,
      'createdAt': createdAt.toIso8601String(),
      'isRead': isRead,
    };
  }

  factory AppNotification.fromMap(Map<String, dynamic> map) {
    return AppNotification(
      id: map['id'] ?? '',
      title: map['title'] ?? '',
      body: map['body'] ?? '',
      type: NotificationType.fromValue(map['type']),
      data: Map<String, dynamic>.from(map['data'] ?? const {}),
      createdAt: DateTime.tryParse(map['createdAt'] ?? '') ?? DateTime.now(),
      isRead: map['isRead'] ?? false,
    );
  }

  AppNotification copyWith({
    String? id,
    String? title,
    String? body,
    NotificationType? type,
    Map<String, dynamic>? data,
    DateTime? createdAt,
    bool? isRead,
  }) {
    return AppNotification(
      id: id ?? this.id,
      title: title ?? this.title,
      body: body ?? this.body,
      type: type ?? this.type,
      data: data ?? this.data,
      createdAt: createdAt ?? this.createdAt,
      isRead: isRead ?? this.isRead,
    );
  }
}

class NotificationPreferences {
  final bool dailyRoadmapReminderEnabled;
  final int reminderHour; // 0 - 23
  final int reminderMinute; // 0 - 59
  final List<int> reminderDays; // 1 = Mon ... 7 = Sun
  final bool stageMilestonesEnabled;
  final bool jobAlertsEnabled;
  final bool interviewScorecardsEnabled;
  final bool periodicReminderEnabled;
  final int periodicReminderIntervalMinutes;

  const NotificationPreferences({
    this.dailyRoadmapReminderEnabled = true,
    this.reminderHour = 19, // 7:00 PM default
    this.reminderMinute = 0,
    this.reminderDays = const [1, 2, 3, 4, 5], // Mon - Fri default
    this.stageMilestonesEnabled = true,
    this.jobAlertsEnabled = true,
    this.interviewScorecardsEnabled = true,
    this.periodicReminderEnabled = true,
    this.periodicReminderIntervalMinutes = 2,
  });

  Map<String, dynamic> toMap() {
    return {
      'dailyRoadmapReminderEnabled': dailyRoadmapReminderEnabled,
      'reminderHour': reminderHour,
      'reminderMinute': reminderMinute,
      'reminderDays': reminderDays,
      'stageMilestonesEnabled': stageMilestonesEnabled,
      'jobAlertsEnabled': jobAlertsEnabled,
      'interviewScorecardsEnabled': interviewScorecardsEnabled,
      'periodicReminderEnabled': periodicReminderEnabled,
      'periodicReminderIntervalMinutes': periodicReminderIntervalMinutes,
    };
  }

  factory NotificationPreferences.fromMap(Map<String, dynamic> map) {
    return NotificationPreferences(
      dailyRoadmapReminderEnabled: map['dailyRoadmapReminderEnabled'] ?? true,
      reminderHour: (map['reminderHour'] as num?)?.toInt() ?? 19,
      reminderMinute: (map['reminderMinute'] as num?)?.toInt() ?? 0,
      reminderDays: List<int>.from(
        map['reminderDays'] ?? const [1, 2, 3, 4, 5],
      ),
      stageMilestonesEnabled: map['stageMilestonesEnabled'] ?? true,
      jobAlertsEnabled: map['jobAlertsEnabled'] ?? true,
      interviewScorecardsEnabled: map['interviewScorecardsEnabled'] ?? true,
      periodicReminderEnabled: map['periodicReminderEnabled'] ?? true,
      periodicReminderIntervalMinutes:
          (map['periodicReminderIntervalMinutes'] as num?)?.toInt() ?? 2,
    );
  }

  NotificationPreferences copyWith({
    bool? dailyRoadmapReminderEnabled,
    int? reminderHour,
    int? reminderMinute,
    List<int>? reminderDays,
    bool? stageMilestonesEnabled,
    bool? jobAlertsEnabled,
    bool? interviewScorecardsEnabled,
    bool? periodicReminderEnabled,
    int? periodicReminderIntervalMinutes,
  }) {
    return NotificationPreferences(
      dailyRoadmapReminderEnabled:
          dailyRoadmapReminderEnabled ?? this.dailyRoadmapReminderEnabled,
      reminderHour: reminderHour ?? this.reminderHour,
      reminderMinute: reminderMinute ?? this.reminderMinute,
      reminderDays: reminderDays ?? this.reminderDays,
      stageMilestonesEnabled:
          stageMilestonesEnabled ?? this.stageMilestonesEnabled,
      jobAlertsEnabled: jobAlertsEnabled ?? this.jobAlertsEnabled,
      interviewScorecardsEnabled:
          interviewScorecardsEnabled ?? this.interviewScorecardsEnabled,
      periodicReminderEnabled:
          periodicReminderEnabled ?? this.periodicReminderEnabled,
      periodicReminderIntervalMinutes:
          periodicReminderIntervalMinutes ??
          this.periodicReminderIntervalMinutes,
    );
  }
}

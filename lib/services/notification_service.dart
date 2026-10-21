import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../models/mock_interview_model.dart';
import '../models/notification_model.dart';
import 'api_service.dart';
import 'firestore_service.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  final FirestoreService _firestoreService = FirestoreService();
  final ApiService _apiService = ApiService();

  bool _isInitialized = false;

  static const String channelId = 'career_pilot_alerts';
  static const String channelName = 'CareerPilot Notifications';
  static const String channelDescription =
      'Learning roadmap reminders, new job alerts, and mock interview scorecards';

  static const int roadmapReminderNotificationId = 101;
  static const int milestoneNotificationId = 102;
  static const int jobAlertNotificationId = 103;
  static const int interviewNotificationId = 104;

  /// Initializes timezone data and local notification channel settings.
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      tz.initializeTimeZones();
    } catch (e) {
      debugPrint('Timezone initialization warning: $e');
    }

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const darwinSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
      macOS: darwinSettings,
    );

    await _localNotifications.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        debugPrint('Notification clicked with payload: ${response.payload}');
      },
    );

    // Create high-importance Android channel
    final androidChannel = AndroidNotificationChannel(
      channelId,
      channelName,
      description: channelDescription,
      importance: Importance.high,
      enableVibration: true,
      playSound: true,
    );

    final androidImplementation = _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    if (androidImplementation != null) {
      await androidImplementation.createNotificationChannel(androidChannel);
    }

    _isInitialized = true;
  }

  /// Requests notification permissions on Android 13+ and iOS.
  Future<bool> requestPermissions() async {
    final androidImplementation = _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    if (androidImplementation != null) {
      final granted = await androidImplementation
          .requestNotificationsPermission();
      return granted ?? false;
    }

    final iOSImplementation = _localNotifications
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();

    if (iOSImplementation != null) {
      final granted = await iOSImplementation.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      return granted ?? false;
    }

    return true;
  }

  // =========================================================================
  // 1. DAILY ROADMAP REMINDERS
  // =========================================================================

  /// Schedules daily roadmap learning reminder according to user preferences.
  Future<void> scheduleDailyRoadmapReminder({
    required String uid,
    required NotificationPreferences prefs,
    required String targetRole,
  }) async {
    await initialize();

    // Cancel existing reminder
    await _localNotifications.cancel(id: roadmapReminderNotificationId);

    if (!prefs.dailyRoadmapReminderEnabled) return;

    final now = tz.TZDateTime.now(tz.local);
    var scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      prefs.reminderHour,
      prefs.reminderMinute,
    );

    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    const androidDetails = AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: channelDescription,
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );

    const notificationDetails = NotificationDetails(android: androidDetails);

    final roleLabel = targetRole.isNotEmpty ? targetRole : 'Career Goal';

    try {
      await _localNotifications.zonedSchedule(
        id: roadmapReminderNotificationId,
        title: 'Daily Learning Goal: $roleLabel 🚀',
        body:
            'Spend 15 minutes advancing your career roadmap today. Keep your momentum strong!',
        scheduledDate: scheduledDate,
        notificationDetails: notificationDetails,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
        payload: 'roadmap',
      );
    } catch (e) {
      debugPrint('Could not schedule local notification: $e');
    }
  }

  // =========================================================================
  // 2. ROADMAP STAGE & MILESTONE ACHIEVEMENTS
  // =========================================================================

  Future<void> showRoadmapStageCompletedNotification({
    required String uid,
    required int stageNumber,
    required String stageTitle,
  }) async {
    await initialize();

    final title = '🎉 Stage $stageNumber Completed!';
    final body =
        'Congratulations on conquering "$stageTitle". Ready to take on the next milestone?';

    final notification = AppNotification(
      id: 'milestone_${DateTime.now().millisecondsSinceEpoch}',
      title: title,
      body: body,
      type: NotificationType.roadmapMilestone,
      data: {'stageNumber': stageNumber, 'stageTitle': stageTitle},
      createdAt: DateTime.now(),
    );

    // Save in Firestore Notification Centre
    try {
      await _firestoreService.saveNotification(uid, notification);
    } catch (_) {}

    // Display local banner
    const androidDetails = AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: channelDescription,
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );

    try {
      await _localNotifications.show(
        id: milestoneNotificationId,
        title: title,
        body: body,
        notificationDetails: const NotificationDetails(android: androidDetails),
        payload: 'roadmap',
      );
    } catch (_) {}
  }

  // =========================================================================
  // 3. NEW JOB OPPORTUNITY ALERTS (LAUNCH / REFRESH DIFF)
  // =========================================================================

  Future<void> checkAndNotifyNewJobs({
    required String uid,
    required String careerGoal,
  }) async {
    if (uid.isEmpty) return;

    try {
      final prefs = await _firestoreService.getNotificationPreferences(uid);
      if (!prefs.jobAlertsEnabled) return;

      // 1. Get previously seen job IDs for this user
      final seenJobIds = await _firestoreService.getSeenJobIds(uid);

      // 2. Fetch latest live jobs matching user target role
      final query = ApiService.mapGoalToSearchQuery(careerGoal);
      final liveJobs = await _apiService.getJobs(search: query, limit: 15);

      if (liveJobs.isEmpty) return;

      // 3. Find genuinely new jobs not in seenJobIds
      final newJobs = liveJobs
          .where((job) => !seenJobIds.contains(job.id))
          .toList();

      if (newJobs.isEmpty) return;

      // 4. Alert user about the top new matching job
      final topJob = newJobs.first;
      final title = '💼 New Job Match: ${topJob.title}';
      final body =
          '${topJob.company} is hiring for ${topJob.title} (${topJob.location}). Tap to apply.';

      final notification = AppNotification(
        id: 'job_${topJob.id}',
        title: title,
        body: body,
        type: NotificationType.jobAlert,
        data: {
          'jobId': topJob.id,
          'jobTitle': topJob.title,
          'company': topJob.company,
          'url': topJob.url,
        },
        createdAt: DateTime.now(),
      );

      // Save in Firestore Notification Centre
      await _firestoreService.saveNotification(uid, notification);

      // Record seen IDs to prevent duplicate alerts
      final allNewIds = newJobs.map((j) => j.id).toList();
      await _firestoreService.recordSeenJobIds(uid, allNewIds);

      // Trigger local banner notification
      await initialize();
      const androidDetails = AndroidNotificationDetails(
        channelId,
        channelName,
        channelDescription: channelDescription,
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
      );

      await _localNotifications.show(
        id: jobAlertNotificationId,
        title: title,
        body: body,
        notificationDetails: const NotificationDetails(android: androidDetails),
        payload: 'careers',
      );
    } catch (e) {
      debugPrint('Background job check error: $e');
    }
  }

  // =========================================================================
  // 4. MOCK INTERVIEW SCORECARD NOTIFICATIONS
  // =========================================================================

  Future<void> showMockInterviewCompletedNotification({
    required String uid,
    required MockInterviewSession session,
  }) async {
    await initialize();

    final title = '📊 Interview Scorecard: ${session.overallScore}%';
    final body =
        'Completed ${session.role} simulation (${session.difficulty}). Strengths and model answers are ready for review.';

    final notification = AppNotification(
      id: 'interview_${session.id}',
      title: title,
      body: body,
      type: NotificationType.interviewScorecard,
      data: {
        'sessionId': session.id,
        'role': session.role,
        'score': session.overallScore,
      },
      createdAt: DateTime.now(),
    );

    // Save in Firestore Notification Centre
    try {
      await _firestoreService.saveNotification(uid, notification);
    } catch (_) {}

    // Display local banner
    const androidDetails = AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: channelDescription,
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );

    try {
      await _localNotifications.show(
        id: interviewNotificationId,
        title: title,
        body: body,
        notificationDetails: const NotificationDetails(android: androidDetails),
        payload: 'interview_${session.id}',
      );
    } catch (_) {}
  }
}

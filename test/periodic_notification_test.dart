import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:career_pilot/models/notification_model.dart';
import 'package:career_pilot/services/notification_service.dart';

void main() {
  AndroidFlutterLocalNotificationsPlugin.registerWith();
  TestWidgetsFlutterBinding.ensureInitialized();

  const MethodChannel channel = MethodChannel(
    'dexterous.com/flutter/local_notifications',
  );
  final List<MethodCall> log = <MethodCall>[];

  setUpAll(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall call) async {
          log.add(call);
          if (call.method == 'initialize') return true;
          if (call.method == 'requestNotificationsPermission') return true;
          if (call.method == 'areNotificationsEnabled') return true;
          return null;
        });
  });

  tearDownAll(() {
    debugDefaultTargetPlatformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  setUp(() {
    log.clear();
  });

  group('Recurring 2-Minute Notification Tests', () {
    test(
      'NotificationPreferences includes periodicReminderEnabled and periodicReminderIntervalMinutes (default: 2 mins)',
      () {
        const defaultPrefs = NotificationPreferences();
        expect(defaultPrefs.periodicReminderEnabled, isTrue);
        expect(defaultPrefs.periodicReminderIntervalMinutes, 2);

        final disabledPrefs = defaultPrefs.copyWith(
          periodicReminderEnabled: false,
          periodicReminderIntervalMinutes: 5,
        );
        expect(disabledPrefs.periodicReminderEnabled, isFalse);
        expect(disabledPrefs.periodicReminderIntervalMinutes, 5);

        final map = disabledPrefs.toMap();
        expect(map['periodicReminderEnabled'], isFalse);
        expect(map['periodicReminderIntervalMinutes'], 5);

        final restored = NotificationPreferences.fromMap(map);
        expect(restored.periodicReminderEnabled, isFalse);
        expect(restored.periodicReminderIntervalMinutes, 5);
      },
    );

    test(
      'Career reminder rotating messages contain all 6 required prompts',
      () {
        final messages = NotificationService.careerReminderMessages;
        expect(messages.length, 6);
        expect(messages, contains('Time to work on your career roadmap!'));
        expect(
          messages,
          contains('Spend a few minutes improving your skills today.'),
        );
        expect(
          messages,
          contains('Have you checked the latest job opportunities?'),
        );
        expect(
          messages,
          contains('Keep going! Small steps lead to career success.'),
        );
        expect(messages, contains('Ready to practise a mock interview?'));
        expect(
          messages,
          contains("Don't forget to update your roadmap progress."),
        );
      },
    );

    test(
      'schedulePeriodicCareerReminders schedules rolling window with exactAllowWhileIdle and rotates messages',
      () async {
        final service = NotificationService();
        final success = await service.schedulePeriodicCareerReminders(
          intervalMinutes: 2,
          forceReschedule: true,
        );

        expect(success, isTrue);
        expect(service.isPeriodicReminderActive, isTrue);

        final zonedCalls = log
            .where((c) => c.method == 'zonedSchedule')
            .toList();
        expect(
          zonedCalls.length,
          NotificationService.periodicReminderQueueSize,
        );

        // Verify rotating message sequence on scheduled items
        for (int i = 0; i < zonedCalls.length; i++) {
          final args = Map<String, dynamic>.from(
            zonedCalls[i].arguments as Map,
          );
          final expectedMsg =
              NotificationService.careerReminderMessages[i %
                  NotificationService.careerReminderMessages.length];
          expect(args['title'], 'CareerPilot Reminder');
          expect(args['body'], expectedMsg);
          expect(args['id'], NotificationService.periodicReminderBaseId + i);
        }

        // Clean up
        await service.cancelPeriodicCareerReminders();
      },
    );

    test(
      'prevents duplicate schedules when already active and forceReschedule is false',
      () async {
        final service = NotificationService();

        // First schedule
        await service.schedulePeriodicCareerReminders(
          intervalMinutes: 2,
          forceReschedule: true,
        );
        final initialZonedCount = log
            .where((c) => c.method == 'zonedSchedule')
            .length;
        expect(
          initialZonedCount,
          NotificationService.periodicReminderQueueSize,
        );

        // Second call without forceReschedule should be a no-op
        final secondCallSuccess = await service.schedulePeriodicCareerReminders(
          intervalMinutes: 2,
        );
        expect(secondCallSuccess, isTrue);

        // Count remains identical because duplicate schedule was prevented
        final newZonedCount = log
            .where((c) => c.method == 'zonedSchedule')
            .length;
        expect(newZonedCount, initialZonedCount);

        // Clean up
        await service.cancelPeriodicCareerReminders();
      },
    );

    test(
      'cancelPeriodicCareerReminders cancels all scheduled alarm IDs and stops active state',
      () async {
        final service = NotificationService();
        await service.schedulePeriodicCareerReminders(
          intervalMinutes: 2,
          forceReschedule: true,
        );
        expect(service.isPeriodicReminderActive, isTrue);

        log.clear();
        await service.cancelPeriodicCareerReminders();

        expect(service.isPeriodicReminderActive, isFalse);

        final cancelCalls = log.where((c) => c.method == 'cancel').toList();
        expect(
          cancelCalls.length,
          NotificationService.periodicReminderQueueSize,
        );

        // Verify all IDs from 200 to 219 were cancelled
        for (int i = 0; i < cancelCalls.length; i++) {
          final args = cancelCalls[i].arguments;
          final int? id = args is int
              ? args
              : (args is Map ? args['id'] as int? : null);
          expect(id, NotificationService.periodicReminderBaseId + i);
        }
      },
    );

    test(
      'triggerSingleCareerReminder cycles message index sequentially',
      () async {
        final service = NotificationService();

        log.clear();
        final initialIndex = service.currentMessageIndex;

        await service.triggerSingleCareerReminder();
        final showCalls1 = log.where((c) => c.method == 'show').toList();
        expect(showCalls1.length, 1);
        final args1 = Map<String, dynamic>.from(
          showCalls1.first.arguments as Map,
        );
        expect(args1['title'], 'CareerPilot Reminder');
        expect(
          args1['body'],
          NotificationService.careerReminderMessages[initialIndex %
              NotificationService.careerReminderMessages.length],
        );

        await service.triggerSingleCareerReminder();
        final showCalls2 = log.where((c) => c.method == 'show').toList();
        expect(showCalls2.length, 2);
        final args2 = Map<String, dynamic>.from(
          showCalls2.last.arguments as Map,
        );
        expect(
          args2['body'],
          NotificationService.careerReminderMessages[(initialIndex + 1) %
              NotificationService.careerReminderMessages.length],
        );
      },
    );
  });
}

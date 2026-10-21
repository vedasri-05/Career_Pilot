import 'package:flutter_test/flutter_test.dart';
import 'package:career_pilot/models/notification_model.dart';

void main() {
  group('Smart Notification Model & Preference Tests', () {
    test(
      'NotificationType enum converts to and from string values accurately',
      () {
        for (final type in NotificationType.values) {
          final stringVal = type.toValue();
          final parsed = NotificationType.fromValue(stringVal);
          expect(parsed, type);
        }
        expect(
          NotificationType.fromValue('invalid_string'),
          NotificationType.general,
        );
      },
    );

    test(
      'AppNotification toMap and fromMap serialization roundtrip preserves state',
      () {
        final notif = AppNotification(
          id: 'notif_123',
          title: '💼 New Job Match: Senior Flutter Dev',
          body: 'Acme Corp is hiring for Senior Flutter Dev (Remote).',
          type: NotificationType.jobAlert,
          data: {'jobId': 'job_77', 'jobTitle': 'Senior Flutter Dev'},
          createdAt: DateTime.now(),
          isRead: false,
        );

        final map = notif.toMap();
        final reconstructed = AppNotification.fromMap(map);

        expect(reconstructed.id, notif.id);
        expect(reconstructed.title, notif.title);
        expect(reconstructed.body, notif.body);
        expect(reconstructed.type, NotificationType.jobAlert);
        expect(reconstructed.data['jobId'], 'job_77');
        expect(reconstructed.isRead, false);
      },
    );

    test(
      'NotificationPreferences serialization and copyWith work as expected',
      () {
        const defaultPrefs = NotificationPreferences();
        expect(defaultPrefs.dailyRoadmapReminderEnabled, isTrue);
        expect(defaultPrefs.reminderHour, 19);
        expect(defaultPrefs.reminderMinute, 0);

        final customized = defaultPrefs.copyWith(
          reminderHour: 20,
          reminderMinute: 30,
          jobAlertsEnabled: false,
        );

        expect(customized.reminderHour, 20);
        expect(customized.reminderMinute, 30);
        expect(customized.jobAlertsEnabled, isFalse);
        expect(customized.dailyRoadmapReminderEnabled, isTrue);

        final map = customized.toMap();
        final restored = NotificationPreferences.fromMap(map);

        expect(restored.reminderHour, 20);
        expect(restored.reminderMinute, 30);
        expect(restored.jobAlertsEnabled, isFalse);
        expect(restored.stageMilestonesEnabled, isTrue);
      },
    );
  });
}

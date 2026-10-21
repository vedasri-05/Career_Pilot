import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../models/notification_model.dart';
import '../../services/firestore_service.dart';
import '../../services/notification_service.dart';
import '../../services/roadmap_service.dart';
import '../../theme/app_theme.dart';
import '../careers/careers_screen.dart';
import '../interview/interview_hub_screen.dart';
import '../roadmap/career_path_form_screen.dart';
import '../roadmap/roadmap_screen.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final FirestoreService _firestoreService = FirestoreService();

  String _filter = 'All'; // 'All', 'Unread', 'Jobs', 'Roadmap', 'Interviews'

  User? get _currentUser => FirebaseAuth.instance.currentUser;

  Color _getTypeColor(NotificationType type) {
    switch (type) {
      case NotificationType.jobAlert:
        return const Color(0xFF059669);
      case NotificationType.roadmapMilestone:
      case NotificationType.roadmapReminder:
        return AppTheme.violet;
      case NotificationType.interviewScorecard:
        return AppTheme.amber;
      case NotificationType.careerReminder:
        return AppTheme.teal;
      case NotificationType.general:
        return AppTheme.primaryBlue;
    }
  }

  IconData _getTypeIcon(NotificationType type) {
    switch (type) {
      case NotificationType.jobAlert:
        return Icons.work_outline_rounded;
      case NotificationType.roadmapMilestone:
        return Icons.emoji_events_outlined;
      case NotificationType.roadmapReminder:
        return Icons.alt_route_rounded;
      case NotificationType.interviewScorecard:
        return Icons.record_voice_over_rounded;
      case NotificationType.careerReminder:
        return Icons.schedule_rounded;
      case NotificationType.general:
        return Icons.notifications_none_rounded;
    }
  }

  Future<void> _handleNotificationTap(AppNotification notif) async {
    final uid = _currentUser?.uid;
    if (uid != null && !notif.isRead) {
      await _firestoreService.markNotificationAsRead(uid, notif.id);
    }

    if (!mounted) return;

    switch (notif.type) {
      case NotificationType.jobAlert:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => CareersScreen(
              initialSearchQuery: notif.data['jobTitle'] as String?,
            ),
          ),
        );
        break;

      case NotificationType.roadmapMilestone:
      case NotificationType.roadmapReminder:
        final cached = RoadmapService.currentRoadmap;
        if (cached != null) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => RoadmapScreen(roadmap: cached),
            ),
          );
        } else if (uid != null) {
          final saved = await RoadmapService.loadUserRoadmap(uid);
          if (saved != null && mounted) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => RoadmapScreen(roadmap: saved),
              ),
            );
          } else if (mounted) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const CareerPathFormScreen(),
              ),
            );
          }
        }
        break;

      case NotificationType.interviewScorecard:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const InterviewHubScreen()),
        );
        break;

      case NotificationType.careerReminder:
        final cached = RoadmapService.currentRoadmap;
        if (cached != null) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => RoadmapScreen(roadmap: cached),
            ),
          );
        }
        break;

      case NotificationType.general:
        break;
    }
  }

  void _openPreferencesSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const _NotificationPreferencesSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final uid = _currentUser?.uid ?? '';

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Notification Centre',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            tooltip: 'Reminder Preferences',
            icon: const Icon(Icons.tune_rounded),
            onPressed: _openPreferencesSheet,
          ),
          if (uid.isNotEmpty)
            IconButton(
              tooltip: 'Mark All Read',
              icon: const Icon(Icons.done_all_rounded),
              onPressed: () async {
                await _firestoreService.markAllNotificationsAsRead(uid);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('All notifications marked as read.'),
                      backgroundColor: AppTheme.darkBlue,
                    ),
                  );
                }
              },
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Filter Chips Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: Colors.white,
              child: SizedBox(
                height: 38,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    _buildFilterChip('All'),
                    _buildFilterChip('Unread'),
                    _buildFilterChip('Jobs'),
                    _buildFilterChip('Roadmap'),
                    _buildFilterChip('Interviews'),
                  ],
                ),
              ),
            ),
            const Divider(height: 1),

            // Notification List
            Expanded(
              child: uid.isEmpty
                  ? const Center(child: Text('Please log in to view alerts.'))
                  : StreamBuilder<List<AppNotification>>(
                      stream: _firestoreService.getNotificationsStream(uid),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }

                        var list = snapshot.data ?? [];

                        // Apply client-side filters
                        if (_filter == 'Unread') {
                          list = list.where((n) => !n.isRead).toList();
                        } else if (_filter == 'Jobs') {
                          list = list
                              .where((n) => n.type == NotificationType.jobAlert)
                              .toList();
                        } else if (_filter == 'Roadmap') {
                          list = list
                              .where(
                                (n) =>
                                    n.type ==
                                        NotificationType.roadmapMilestone ||
                                    n.type == NotificationType.roadmapReminder,
                              )
                              .toList();
                        } else if (_filter == 'Interviews') {
                          list = list
                              .where(
                                (n) =>
                                    n.type ==
                                    NotificationType.interviewScorecard,
                              )
                              .toList();
                        }

                        if (list.isEmpty) {
                          return Center(
                            child: Padding(
                              padding: const EdgeInsets.all(32),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    width: 72,
                                    height: 72,
                                    decoration: BoxDecoration(
                                      color: AppTheme.primaryBlue.withValues(
                                        alpha: 0.08,
                                      ),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.notifications_none_rounded,
                                      size: 36,
                                      color: AppTheme.primaryBlue,
                                    ),
                                  ),
                                  const SizedBox(height: 18),
                                  const Text(
                                    'No notifications',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.textDark,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    _filter == 'All'
                                        ? 'You are all caught up! New job matches, roadmap milestones, and interview scorecards will appear here.'
                                        : 'No notifications matching the "$_filter" filter.',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      color: AppTheme.textMedium,
                                      fontSize: 13.5,
                                      height: 1.4,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }

                        return ListView.builder(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          itemCount: list.length,
                          itemBuilder: (context, index) {
                            final notif = list[index];
                            return _buildNotificationTile(uid, notif);
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label) {
    final isSelected = _filter == label;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        selectedColor: AppTheme.primaryBlue,
        backgroundColor: const Color(0xFFF1F5F9),
        checkmarkColor: Colors.white,
        labelStyle: TextStyle(
          fontSize: 12.5,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          color: isSelected ? Colors.white : AppTheme.textDark,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        side: BorderSide(
          color: isSelected ? AppTheme.primaryBlue : const Color(0xFFE2E8F0),
        ),
        onSelected: (_) {
          setState(() {
            _filter = label;
          });
        },
      ),
    );
  }

  Widget _buildNotificationTile(String uid, AppNotification notif) {
    final color = _getTypeColor(notif.type);
    final icon = _getTypeIcon(notif.type);

    return Dismissible(
      key: Key(notif.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: AppTheme.rose,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      onDismissed: (_) {
        _firestoreService.deleteNotification(uid, notif.id);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: notif.isRead ? Colors.white : const Color(0xFFF0F7FF),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: notif.isRead
                ? const Color(0xFFE2E8F0)
                : AppTheme.primaryBlue.withValues(alpha: 0.35),
            width: notif.isRead ? 1 : 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 8,
          ),
          onTap: () => _handleNotificationTap(notif),
          leading: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  notif.title,
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: notif.isRead
                        ? FontWeight.w600
                        : FontWeight.bold,
                    color: AppTheme.textDark,
                  ),
                ),
              ),
              if (!notif.isRead)
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: AppTheme.primaryBlue,
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 4),
              Text(
                notif.body,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12.5,
                  color: AppTheme.textMedium,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _formatTimeAgo(notif.createdAt),
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.shade500,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTimeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}

class _NotificationPreferencesSheet extends StatefulWidget {
  const _NotificationPreferencesSheet();

  @override
  State<_NotificationPreferencesSheet> createState() =>
      _NotificationPreferencesSheetState();
}

class _NotificationPreferencesSheetState
    extends State<_NotificationPreferencesSheet> {
  final FirestoreService _firestoreService = FirestoreService();
  final NotificationService _notificationService = NotificationService();

  bool _isLoading = true;
  late NotificationPreferences _prefs;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      final p = await _firestoreService.getNotificationPreferences(uid);
      if (mounted) {
        setState(() {
          _prefs = p;
          _isLoading = false;
        });
      }
    } else {
      if (mounted) {
        setState(() {
          _prefs = const NotificationPreferences();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _savePreferences() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      await _firestoreService.saveNotificationPreferences(uid, _prefs);

      // Reschedule local roadmap reminders
      final profile = await _firestoreService.getUserProfile(uid);
      await _notificationService.scheduleDailyRoadmapReminder(
        uid: uid,
        prefs: _prefs,
        targetRole: profile?.careerGoal ?? 'Career Path',
      );

      // Reschedule or cancel recurring career reminders
      if (_prefs.periodicReminderEnabled) {
        await _notificationService.schedulePeriodicCareerReminders(
          intervalMinutes: _prefs.periodicReminderIntervalMinutes,
          forceReschedule: true,
        );
      } else {
        await _notificationService.cancelPeriodicCareerReminders();
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Notification settings updated.'),
            backgroundColor: Color(0xFF059669),
          ),
        );
      }
    }
  }

  Future<void> _pickTime() async {
    final initialTime = TimeOfDay(
      hour: _prefs.reminderHour,
      minute: _prefs.reminderMinute,
    );

    final selected = await showTimePicker(
      context: context,
      initialTime: initialTime,
    );

    if (selected != null) {
      setState(() {
        _prefs = _prefs.copyWith(
          reminderHour: selected.hour,
          reminderMinute: selected.minute,
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Container(
        height: 250,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    final hourStr = _prefs.reminderHour.toString().padLeft(2, '0');
    final minuteStr = _prefs.reminderMinute.toString().padLeft(2, '0');

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'Notification Preferences',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppTheme.textDark,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Control daily learning reminders and alert notifications.',
            style: TextStyle(fontSize: 13, color: AppTheme.textMedium),
          ),
          const SizedBox(height: 18),

          // Daily Roadmap Reminder Toggle
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text(
              'Daily Roadmap Learning Reminder',
              style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold),
            ),
            subtitle: const Text(
              'Remind me to spend 15 minutes advancing my roadmap',
              style: TextStyle(fontSize: 12),
            ),
            value: _prefs.dailyRoadmapReminderEnabled,
            activeThumbColor: AppTheme.primaryBlue,
            onChanged: (val) {
              setState(() {
                _prefs = _prefs.copyWith(dailyRoadmapReminderEnabled: val);
              });
            },
          ),

          // Reminder Time Picker
          if (_prefs.dailyRoadmapReminderEnabled) ...[
            const SizedBox(height: 8),
            InkWell(
              onTap: _pickTime,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Reminder Time',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Row(
                      children: [
                        Text(
                          '$hourStr:$minuteStr',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryBlue,
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Icon(
                          Icons.access_time_rounded,
                          size: 18,
                          color: AppTheme.primaryBlue,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],

          // 2-Minute Career Reminders Toggle
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text(
              '2-Minute Career Reminders',
              style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold),
            ),
            subtitle: const Text(
              'Receive rotating career tips & check-ins every 2 minutes',
              style: TextStyle(fontSize: 12),
            ),
            value: _prefs.periodicReminderEnabled,
            activeThumbColor: AppTheme.primaryBlue,
            onChanged: (val) {
              setState(() {
                _prefs = _prefs.copyWith(periodicReminderEnabled: val);
              });
            },
          ),

          const Divider(),

          // New Job Alerts Toggle
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text(
              'New Job Match Alerts',
              style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold),
            ),
            subtitle: const Text(
              'Alert when new remote roles match your career goal',
              style: TextStyle(fontSize: 12),
            ),
            value: _prefs.jobAlertsEnabled,
            activeThumbColor: AppTheme.primaryBlue,
            onChanged: (val) {
              setState(() {
                _prefs = _prefs.copyWith(jobAlertsEnabled: val);
              });
            },
          ),

          // Milestone Celebrations Toggle
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text(
              'Roadmap Milestone Celebrations',
              style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold),
            ),
            subtitle: const Text(
              'Celebrate completed learning stages and projects',
              style: TextStyle(fontSize: 12),
            ),
            value: _prefs.stageMilestonesEnabled,
            activeThumbColor: AppTheme.primaryBlue,
            onChanged: (val) {
              setState(() {
                _prefs = _prefs.copyWith(stageMilestonesEnabled: val);
              });
            },
          ),

          // Interview Scorecards Toggle
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text(
              'Mock Interview Scorecards',
              style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold),
            ),
            subtitle: const Text(
              'Receive evaluation reports when interviews conclude',
              style: TextStyle(fontSize: 12),
            ),
            value: _prefs.interviewScorecardsEnabled,
            activeThumbColor: AppTheme.primaryBlue,
            onChanged: (val) {
              setState(() {
                _prefs = _prefs.copyWith(interviewScorecardsEnabled: val);
              });
            },
          ),

          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: _savePreferences,
              child: const Text('Save Preferences'),
            ),
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }
}

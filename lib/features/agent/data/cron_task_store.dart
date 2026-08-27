import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pocketstrike/core/services/notification_service.dart';
import 'package:pocketstrike/core/storage/prefs_provider.dart';
import 'package:pocketstrike/features/agent/domain/agent_tool.dart';
import 'package:pocketstrike/features/chat/application/chat_controller.dart';
import 'package:pocketstrike/features/telegram/telegram_service.dart';

enum CronTaskType { oneShot, recurring }

class CronTask {
  const CronTask({
    required this.id,
    required this.title,
    required this.prompt,
    required this.type,
    required this.nextRunAt,
    this.recurringSchedule,
    this.isActive = true,
    required this.createdAt,
    this.lastRunAt,
  });

  final String id;
  final String title;
  final String prompt;
  final CronTaskType type;
  final DateTime nextRunAt;
  final String? recurringSchedule;
  final bool isActive;
  final DateTime createdAt;
  final DateTime? lastRunAt;

  CronTask copyWith({
    String? id,
    String? title,
    String? prompt,
    CronTaskType? type,
    DateTime? nextRunAt,
    String? recurringSchedule,
    bool? isActive,
    DateTime? createdAt,
    DateTime? lastRunAt,
  }) {
    return CronTask(
      id: id ?? this.id,
      title: title ?? this.title,
      prompt: prompt ?? this.prompt,
      type: type ?? this.type,
      nextRunAt: nextRunAt ?? this.nextRunAt,
      recurringSchedule: recurringSchedule ?? this.recurringSchedule,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      lastRunAt: lastRunAt ?? this.lastRunAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'prompt': prompt,
        'type': type.name,
        'nextRunAt': nextRunAt.toIso8601String(),
        'recurringSchedule': recurringSchedule,
        'isActive': isActive,
        'createdAt': createdAt.toIso8601String(),
        'lastRunAt': lastRunAt?.toIso8601String(),
      };

  factory CronTask.fromJson(Map<String, dynamic> json) => CronTask(
        id: json['id'] as String,
        title: json['title'] as String,
        prompt: json['prompt'] as String,
        type: CronTaskType.values.firstWhere(
          (e) => e.name == json['type'],
          orElse: () => CronTaskType.oneShot,
        ),
        nextRunAt: DateTime.parse(json['nextRunAt'] as String),
        recurringSchedule: json['recurringSchedule'] as String?,
        isActive: json['isActive'] as bool? ?? true,
        createdAt: DateTime.parse(json['createdAt'] as String),
        lastRunAt: json['lastRunAt'] != null
            ? DateTime.parse(json['lastRunAt'] as String)
            : null,
      );
}

final cronTaskProvider =
    NotifierProvider<CronTaskNotifier, List<CronTask>>(CronTaskNotifier.new);

class CronTaskNotifier extends Notifier<List<CronTask>> {
  static const _kStorageKey = 'pocketstrike_cron_tasks';
  Timer? _ticker;

  @override
  List<CronTask> build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    final raw = prefs.getString(_kStorageKey);
    List<CronTask> loaded = [];
    if (raw != null && raw.isNotEmpty) {
      try {
        final list = jsonDecode(raw) as List;
        loaded = list.map((e) => CronTask.fromJson(e as Map<String, dynamic>)).toList();
      } catch (_) {}
    }

    _startBackgroundTicker();

    ref.onDispose(() {
      _ticker?.cancel();
    });

    return loaded;
  }

  void _startBackgroundTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 3), (_) => _checkPendingTasks());
  }

  Future<void> _save(List<CronTask> tasks) async {
    state = tasks;
    final prefs = ref.read(sharedPreferencesProvider);
    final jsonStr = jsonEncode(tasks.map((t) => t.toJson()).toList());
    await prefs.setString(_kStorageKey, jsonStr);
  }

  Future<void> addTask(CronTask task) async {
    final updated = [...state, task];
    await _save(updated);
  }

  Future<void> deleteTask(String id) async {
    final updated = state.where((t) => t.id != id).toList();
    await _save(updated);
  }

  Future<void> cancelTaskByKeyword(String keyword) async {
    final lower = keyword.toLowerCase();
    final updated = state.where((t) {
      final match = t.title.toLowerCase().contains(lower) ||
          t.prompt.toLowerCase().contains(lower);
      return !match;
    }).toList();
    await _save(updated);
  }

  Future<void> toggleTaskActive(String id, bool active) async {
    final updated = state.map((t) {
      if (t.id == id) return t.copyWith(isActive: active);
      return t;
    }).toList();
    await _save(updated);
  }

  Future<void> _checkPendingTasks() async {
    final now = DateTime.now();
    final updated = <CronTask>[];

    for (final task in state) {
      if (task.isActive && now.isAfter(task.nextRunAt)) {
        // Trigger Task Execution!
        _executeTaskTrigger(task);

        if (task.type == CronTaskType.oneShot) {
          // Deactivate one-shot task after firing
          updated.add(task.copyWith(isActive: false, lastRunAt: now));
        } else {
          // Reschedule recurring task
          DateTime nextRun = now.add(const Duration(hours: 24));
          if (task.recurringSchedule == 'hourly') {
            nextRun = now.add(const Duration(hours: 1));
          } else if (task.recurringSchedule == 'every_30m') {
            nextRun = now.add(const Duration(minutes: 30));
          }
          updated.add(task.copyWith(nextRunAt: nextRun, lastRunAt: now));
        }
      } else {
        updated.add(task);
      }
    }

    if (updated.length != state.length ||
        state.any((t) => t.lastRunAt != updated.firstWhere((u) => u.id == t.id).lastRunAt)) {
      await _save(updated);
    }
  }

  Future<void> _executeTaskTrigger(CronTask task) async {
    final title = task.title;
    final prompt = task.prompt;

    // 1. Inject reminder into active Chat thread
    try {
      await ref
          .read(chatControllerProvider.notifier)
          .injectReminderMessage(title, prompt);
    } catch (_) {}

    // 2. Send Telegram notification if connected
    try {
      await ref
          .read(telegramServiceProvider.notifier)
          .postNotification('⏰ *Reminder Alert: $title*\n\n$prompt');
    } catch (_) {}

    // 3. Trigger Android System Notification Banner
    try {
      final notifService = ref.read(notificationServiceProvider);
      await notifService.showNotification(
        id: task.id.hashCode,
        title: '⏰ Reminder: $title',
        body: prompt,
      );
    } catch (_) {}
  }

  /// Agent tools for Task & Cron Job Automation.
  List<AgentTool> buildTools() {
    return [
      AgentTool(
        name: 'schedule_task',
        description:
            'Schedules a one-shot reminder or recurring cron job (e.g. "remind me to drink water in 1 hour" or "daily news at 7 AM").',
        inputSchema: const {
          'type': 'object',
          'properties': {
            'title': {
              'type': 'string',
              'description': 'Short title of the task or reminder (e.g. "Drink Water").',
            },
            'prompt': {
              'type': 'string',
              'description': 'What the agent should remind or do when triggered.',
            },
            'delayMinutes': {
              'type': 'number',
              'description': 'Minutes from now until task fires (for one-shot reminders).',
            },
            'recurringSchedule': {
              'type': 'string',
              'description': 'Optional recurring schedule ("daily_7am", "hourly", "every_30m").',
            },
          },
          'required': ['title', 'prompt'],
        },
        risk: ToolRisk.safe,
        run: (args) async {
          final title = args['title'] as String? ?? 'Scheduled Reminder';
          final promptText = args['prompt'] as String? ?? '';
          final delayVal = (args['delayMinutes'] as num?)?.toDouble() ?? 1.0;
          final delayMinutes = delayVal <= 0 ? 1.0 : delayVal;
          final recurring = args['recurringSchedule'] as String?;
          final now = DateTime.now();
          final fireTime = now.add(Duration(seconds: (delayMinutes * 60).round()));

          final newTask = CronTask(
            id: 'task_${now.millisecondsSinceEpoch}',
            title: title,
            prompt: promptText,
            type: recurring != null ? CronTaskType.recurring : CronTaskType.oneShot,
            nextRunAt: fireTime,
            recurringSchedule: recurring,
            createdAt: now,
          );

          await addTask(newTask);
          final timeStr = '${fireTime.hour.toString().padLeft(2, "0")}:${fireTime.minute.toString().padLeft(2, "0")}';
          return 'Successfully scheduled task "$title" to fire at $timeStr (${delayMinutes.toInt()} minutes from now).';
        },
      ),
      AgentTool(
        name: 'list_scheduled_tasks',
        description: 'Lists all currently active scheduled tasks, reminders, and recurring cron jobs.',
        inputSchema: const {
          'type': 'object',
          'properties': <String, dynamic>{},
        },
        risk: ToolRisk.safe,
        run: (args) async {
          if (state.isEmpty) return 'No scheduled tasks or active cron jobs currently set.';
          final buffer = StringBuffer('Active Scheduled Tasks & Cron Jobs:\n');
          for (final t in state) {
            final activeStr = t.isActive ? '🟢 Active' : '⚪ Paused';
            buffer.writeln('• [${t.id}] ${t.title} ($activeStr)');
            buffer.writeln('   - Prompt: "${t.prompt}"');
            buffer.writeln('   - Next Run: ${t.nextRunAt.toLocal()}');
          }
          return buffer.toString().trim();
        },
      ),
      AgentTool(
        name: 'cancel_scheduled_task',
        description: 'Cancels/deletes a scheduled task or reminder by keyword or description (e.g. "water", "news").',
        inputSchema: const {
          'type': 'object',
          'properties': {
            'keyword': {
              'type': 'string',
              'description': 'Keyword or title of the task to cancel (e.g. "water", "drink", "news").',
            },
          },
          'required': ['keyword'],
        },
        risk: ToolRisk.safe,
        run: (args) async {
          final kw = args['keyword'] as String? ?? '';
          if (kw.trim().isEmpty) return 'Error: Keyword is empty.';
          await cancelTaskByKeyword(kw.trim());
          return 'Successfully cancelled matching tasks for "$kw".';
        },
      ),
    ];
  }
}

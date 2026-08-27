import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pocketstrike/app/theme/glass_tokens.dart';
import 'package:pocketstrike/shared/widgets/app_icons.dart';
import 'package:pocketstrike/shared/widgets/glass_button.dart';
import 'package:pocketstrike/features/agent/data/cron_task_store.dart';

class CronTasksScreen extends ConsumerWidget {
  const CronTasksScreen({super.key});

  void _showAddTaskSheet(BuildContext context, WidgetRef ref) {
    final tokens = context.glass;
    final titleController = TextEditingController();
    final promptController = TextEditingController();
    double delayMinutes = 30;
    bool isRecurring = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) => Container(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: BorderRadius.vertical(top: Radius.circular(tokens.radiusLg)),
            border: Border.all(color: tokens.glassBorder),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(AppIcons.sparkles, color: tokens.accent, size: 20),
                  const SizedBox(width: 8),
                  Text('New Task / Cron Job',
                      style: Theme.of(context).textTheme.titleMedium),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: titleController,
                decoration: InputDecoration(
                  labelText: 'Task Title (e.g. Drink Water)',
                  filled: true,
                  fillColor: tokens.glassColor,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: promptController,
                decoration: InputDecoration(
                  labelText: 'Prompt / Instruction (e.g. Remind me to drink water)',
                  filled: true,
                  fillColor: tokens.glassColor,
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Text('Delay (${delayMinutes.toInt()} mins): '),
                  Expanded(
                    child: Slider(
                      value: delayMinutes,
                      min: 5,
                      max: 240,
                      divisions: 47,
                      activeColor: tokens.accent,
                      onChanged: (val) => setSheetState(() => delayMinutes = val),
                    ),
                  ),
                ],
              ),
              SwitchListTile(
                title: const Text('Recurring Daily Cron Job'),
                value: isRecurring,
                activeThumbColor: tokens.accent,
                onChanged: (val) => setSheetState(() => isRecurring = val),
              ),
              const SizedBox(height: 16),
              GlassButton(
                label: 'Create Scheduled Task',
                icon: AppIcons.plus,
                expanded: true,
                onPressed: () async {
                  if (titleController.text.trim().isEmpty) return;
                  final now = DateTime.now();
                  final newTask = CronTask(
                    id: 'task_${now.millisecondsSinceEpoch}',
                    title: titleController.text.trim(),
                    prompt: promptController.text.trim().isEmpty
                        ? titleController.text.trim()
                        : promptController.text.trim(),
                    type: isRecurring ? CronTaskType.recurring : CronTaskType.oneShot,
                    nextRunAt: now.add(Duration(minutes: delayMinutes.toInt())),
                    recurringSchedule: isRecurring ? 'daily_7am' : null,
                    createdAt: now,
                  );
                  await ref.read(cronTaskProvider.notifier).addTask(newTask);
                  if (context.mounted) Navigator.pop(context);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.glass;
    final tasks = ref.watch(cronTaskProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Scheduled Tasks & Cron Jobs',
          style: Theme.of(context).textTheme.titleMedium,
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddTaskSheet(context, ref),
        backgroundColor: tokens.accent,
        icon: Icon(Icons.add, color: tokens.onAccent),
        label: Text('Add Task', style: TextStyle(color: tokens.onAccent, fontWeight: FontWeight.bold)),
      ),
      body: tasks.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.alarm_off, size: 56, color: tokens.textSecondary),
                  const SizedBox(height: 14),
                  Text('No Active Tasks or Reminders',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 6),
                  Text(
                    'Say "remind me to drink water in 1 hour"\nor tap + Add Task to create a schedule.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: tokens.textSecondary),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: tasks.length,
              itemBuilder: (context, index) {
                final task = tasks[index];
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: tokens.glassColor,
                    borderRadius: BorderRadius.circular(tokens.radiusSm),
                    border: Border.all(color: tokens.glassBorder),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: tokens.accent.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          task.type == CronTaskType.recurring
                              ? Icons.loop
                              : Icons.notifications_active,
                          color: tokens.accent,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              task.title,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleSmall
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              task.prompt,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontSize: 12, color: tokens.textSecondary),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Next Run: ${task.nextRunAt.hour.toString().padLeft(2, "0")}:${task.nextRunAt.minute.toString().padLeft(2, "0")} (${task.type == CronTaskType.recurring ? "Recurring" : "One-Shot"})',
                              style: TextStyle(
                                  fontSize: 11,
                                  color: tokens.accent,
                                  fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                        onPressed: () =>
                            ref.read(cronTaskProvider.notifier).deleteTask(task.id),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}

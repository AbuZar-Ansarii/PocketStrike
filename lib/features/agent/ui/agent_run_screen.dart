import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pocketstrike/app/theme/glass_tokens.dart';
import 'package:pocketstrike/shared/widgets/app_icons.dart';
import 'package:pocketstrike/features/chat/application/chat_controller.dart';
import 'package:pocketstrike/features/chat/ui/widgets/agent_timeline.dart';

/// Full-screen Agent Run Viewer detailing each step, arguments,
/// observations, and safety status.
class AgentRunScreen extends ConsumerWidget {
  const AgentRunScreen({super.key, required this.runId});

  final String runId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.glass;
    final chatState = ref.watch(chatControllerProvider);
    final steps = chatState.steps;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Agent Run Details',
          style: Theme.of(context).textTheme.titleMedium,
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: tokens.glassColor,
              borderRadius: BorderRadius.circular(tokens.radiusSm),
              border: Border.all(color: tokens.glassBorder),
            ),
            child: Row(
              children: [
                Icon(AppIcons.terminal,
                    color: tokens.accent, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Run ID: $runId',
                          style: Theme.of(context).textTheme.titleSmall),
                      const SizedBox(height: 2),
                      Text(
                        'Total steps: ${steps.length} · Status: ${chatState.isGenerating ? "Running..." : "Completed"}',
                        style: TextStyle(color: tokens.textSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          AgentTimeline(steps: steps, running: chatState.isGenerating),
        ],
      ),
    );
  }
}

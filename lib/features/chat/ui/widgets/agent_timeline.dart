import 'package:flutter/material.dart';
import 'package:pocketstrike/app/theme/app_theme.dart';
import 'package:pocketstrike/app/theme/glass_tokens.dart';
import 'package:pocketstrike/shared/widgets/app_icons.dart';
import 'package:pocketstrike/features/agent/domain/agent_event.dart';

/// Modern executive live animated tool-call timeline shown during agent execution (Hermes / OpenClaw style).
class AgentTimeline extends StatefulWidget {
  const AgentTimeline({super.key, required this.steps, this.running = false});

  final List<AgentStep> steps;
  final bool running;

  @override
  State<AgentTimeline> createState() => _AgentTimelineState();
}

class _AgentTimelineState extends State<AgentTimeline> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final tokens = context.glass;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (widget.steps.isEmpty && !widget.running) {
      return const SizedBox.shrink();
    }

    final maxWidth = MediaQuery.of(context).size.width * 0.86;
    final lastStep = widget.steps.isNotEmpty ? widget.steps.last : null;

    String currentActionText;
    if (widget.running) {
      if (lastStep != null && lastStep.type == 'toolCall') {
        currentActionText = 'Running ${lastStep.toolName}…';
      } else if (lastStep != null && lastStep.type == 'observation') {
        currentActionText = 'Analyzing results & planning next step…';
      } else {
        currentActionText = 'Agent planning actions…';
      }
    } else {
      final toolCount = widget.steps.where((s) => s.type == 'toolCall').length;
      currentActionText = 'Agent completed $toolCount action${toolCount == 1 ? '' : 's'}';
    }

    return Align(
      alignment: Alignment.centerLeft,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        constraints: BoxConstraints(maxWidth: maxWidth),
        decoration: BoxDecoration(
          color: tokens.terminalSurface,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
            bottomLeft: Radius.circular(4),
            bottomRight: Radius.circular(16),
          ),
          border: Border.all(
            color: widget.running
                ? tokens.accent.withValues(alpha: 0.45)
                : tokens.glassBorder,
            width: widget.running ? 1.0 : 0.8,
          ),
          boxShadow: widget.running
              ? [
                  BoxShadow(
                    color: tokens.accent.withValues(alpha: 0.16),
                    blurRadius: 12,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => setState(() => _expanded = !_expanded),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                child: Row(
                  children: [
                    // Icon Badge
                    Container(
                      padding: const EdgeInsets.all(4.5),
                      decoration: BoxDecoration(
                        color: tokens.accent.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: tokens.accent.withValues(alpha: 0.3),
                          width: 0.6,
                        ),
                      ),
                      child: Icon(
                        widget.running ? AppIcons.zap : AppIcons.checkCircle2,
                        size: 13,
                        color: tokens.accent,
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Status and action description
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              Text(
                                'Agent Execution',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.3,
                                  color: tokens.accent,
                                ),
                              ),
                              if (widget.steps.isNotEmpty) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 5, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: tokens.accent.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    '${widget.steps.length} step${widget.steps.length == 1 ? '' : 's'}',
                                    style: TextStyle(
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w600,
                                      color: tokens.accent,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 1.5),
                          Text(
                            currentActionText,
                            style: AppTheme.mono(
                              fontSize: 11,
                              color: isDark ? Colors.white70 : theme.colorScheme.onSurface,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),

                    if (widget.running)
                      SizedBox(
                        width: 13,
                        height: 13,
                        child: CircularProgressIndicator(
                          strokeWidth: 1.8,
                          color: tokens.accent,
                        ),
                      )
                    else
                      Icon(
                        _expanded ? AppIcons.chevronUp : AppIcons.chevronDown,
                        size: 14,
                        color: tokens.textSecondary,
                      ),
                  ],
                ),
              ),
            ),
            if (_expanded && widget.steps.isNotEmpty) ...[
              Divider(height: 1, color: tokens.glassBorder),
              Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final step in widget.steps) _StepRow(step: step),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({required this.step});

  final AgentStep step;

  @override
  Widget build(BuildContext context) {
    final tokens = context.glass;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final (marker, color) = switch (step.type) {
      'toolCall' => ('⚡', tokens.accent),
      'observation' when step.isError => ('✗', Colors.redAccent),
      'observation' => ('✓', isDark ? Colors.tealAccent : Colors.teal),
      'denied' => ('⛔', Colors.orangeAccent),
      'error' => ('✗', Colors.redAccent),
      _ => ('•', tokens.textSecondary),
    };

    final detail = switch (step.type) {
      'toolCall' => '${step.toolName}  ${_prettyArgs(step.argumentsJson)}',
      'observation' when step.toolName == 'generate_image' =>
        'Image generated and displayed.',
      'observation' => step.result ?? '',
      'denied' => 'Denied by user: ${step.toolName ?? ''}',
      _ => step.text ?? '',
    };

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(marker, style: AppTheme.mono(fontSize: 11, color: color)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              detail,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              style: AppTheme.mono(
                fontSize: 11,
                color: step.isError
                    ? Colors.redAccent
                    : Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _prettyArgs(String? json) {
    if (json == null || json == '{}') return '';
    return json.length > 120 ? '${json.substring(0, 120)}…' : json;
  }
}


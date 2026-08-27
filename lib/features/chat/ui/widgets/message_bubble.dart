import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pocketstrike/app/theme/app_theme.dart';
import 'package:pocketstrike/app/theme/glass_tokens.dart';
import 'package:pocketstrike/core/db/app_database.dart' show Message;
import 'package:pocketstrike/core/models/chat_models.dart';
import 'package:pocketstrike/shared/widgets/app_icons.dart';
import 'package:pocketstrike/features/chat/application/chat_controller.dart';
import 'package:pocketstrike/features/chat/ui/widgets/markdown_message.dart';

/// Modern chat bubble with executive assistant responses, top 3-dot tool inspector,
/// interactive tool badges, and tight user sizing (Hermes / OpenClaw style).
class MessageBubble extends ConsumerWidget {
  const MessageBubble({
    super.key,
    required this.message,
    this.isStreaming = false,
    this.isLastAssistant = false,
  });

  final Message message;
  final bool isStreaming;
  final bool isLastAssistant;

  List<ToolCallInfo> _getToolCalls() {
    if (message.toolCallsJson == null || message.toolCallsJson!.isEmpty) {
      return const [];
    }
    try {
      final list = jsonDecode(message.toolCallsJson!) as List;
      return list
          .map((e) => ToolCallInfo.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.glass;
    final isUser = message.role == 'user';
    final isTool = message.role == 'tool';

    // Tool messages are incorporated into the assistant message or inspected via modal
    if (isTool) return const SizedBox.shrink();

    final toolCalls = !isUser ? _getToolCalls() : const <ToolCallInfo>[];
    final maxWidth = MediaQuery.of(context).size.width * (isUser ? 0.78 : 0.88);

    final liveTps = isStreaming
        ? ref.watch(chatControllerProvider.select((s) => s.tokensPerSecond))
        : null;
    final cachedTps = ref.watch(chatControllerProvider
        .select((s) => s.messageSpeeds[message.id]));
    final speed = liveTps ?? cachedTps;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        constraints: BoxConstraints(maxWidth: maxWidth),
        decoration: BoxDecoration(
          color: isUser
              ? tokens.accent.withValues(alpha: 0.15)
              : tokens.glassColor,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isUser ? 16 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 16),
          ),
          border: Border.all(
            color: isUser
                ? tokens.accent.withValues(alpha: 0.35)
                : tokens.glassBorder,
            width: 0.8,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        padding: EdgeInsets.symmetric(
          horizontal: isUser ? 12 : 14,
          vertical: isUser ? 8 : 10,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment:
              isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            // Top Header for Assistant Message
            if (!isUser) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Left: Avatar + Title + Tools Badge
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: tokens.accent.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: tokens.accent.withValues(alpha: 0.3),
                            width: 0.6,
                          ),
                        ),
                        child: Icon(AppIcons.sparkles,
                            size: 11, color: tokens.accent),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Strike',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: tokens.accent,
                          letterSpacing: 0.2,
                        ),
                      ),
                      if (toolCalls.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () {
                              HapticFeedback.selectionClick();
                              _showToolInspectorSheet(context, toolCalls);
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: tokens.accent.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: tokens.accent.withValues(alpha: 0.35),
                                  width: 0.6,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(AppIcons.wrench,
                                      size: 10, color: tokens.accent),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${toolCalls.length} tool${toolCalls.length == 1 ? '' : 's'}',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: tokens.accent,
                                    ),
                                  ),
                                  const SizedBox(width: 2),
                                  Icon(Icons.keyboard_arrow_right_rounded,
                                      size: 12, color: tokens.accent),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                      if (isStreaming) ...[
                        const SizedBox(width: 8),
                        _PulsingDot(color: tokens.accent),
                      ],
                    ],
                  ),

                  // Right: 3-Dot More Action Menu
                  _MessageTopMenu(
                    message: message,
                    toolCalls: toolCalls,
                    isLastAssistant: isLastAssistant,
                    isStreaming: isStreaming,
                  ),
                ],
              ),
              const SizedBox(height: 6),
            ],

            if (message.attachmentsJson != null) ...[
              _AttachmentChips(json: message.attachmentsJson!),
              const SizedBox(height: 6),
            ],

            // Content
            if (message.content.isEmpty && isStreaming)
              _ThinkingState(color: tokens.accent)
            else if (isUser)
              SelectableText(
                message.content,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontSize: 14,
                      height: 1.35,
                    ),
              )
            else
              MarkdownMessage(
                text: message.content + (isStreaming ? ' ▍' : ''),
              ),

            const SizedBox(height: 4),

            // Actions & Speed row
            if (isUser)
              Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  _ActionIcon(
                    icon: AppIcons.copy,
                    tooltip: 'Copy',
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: message.content));
                    },
                  ),
                  _ActionIcon(
                    icon: AppIcons.edit,
                    tooltip: 'Edit & resend',
                    onTap: () => _editAndResend(context, ref),
                  ),
                ],
              )
            else
              Row(
                mainAxisSize: MainAxisSize.max,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Left: Action icons
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _ActionIcon(
                        icon: AppIcons.copy,
                        tooltip: 'Copy',
                        onTap: () {
                          Clipboard.setData(
                              ClipboardData(text: message.content));
                        },
                      ),
                      if (isLastAssistant && !isStreaming)
                        _ActionIcon(
                          icon: AppIcons.rotateCcw,
                          tooltip: 'Regenerate',
                          onTap: () => ref
                              .read(chatControllerProvider.notifier)
                              .regenerate(),
                        ),
                    ],
                  ),

                  // Right Bottom: Speed Token Generation Indicator
                  _SpeedBadge(
                    speed: speed,
                    isStreaming: isStreaming,
                    completionTokens: message.completionTokens,
                    tokens: tokens,
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _editAndResend(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController(text: message.content);
    final newText = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Edit message'),
        content: TextField(
          controller: controller,
          maxLines: null,
          autofocus: true,
          decoration: const InputDecoration(border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text),
            child: const Text('Send'),
          ),
        ],
      ),
    );
    if (newText != null && newText.trim().isNotEmpty) {
      await ref
          .read(chatControllerProvider.notifier)
          .editAndResend(message, newText.trim());
    }
  }
}

/// 3-Dot Action Button at the top right of the message bubble
class _MessageTopMenu extends ConsumerWidget {
  const _MessageTopMenu({
    required this.message,
    required this.toolCalls,
    required this.isLastAssistant,
    required this.isStreaming,
  });

  final Message message;
  final List<ToolCallInfo> toolCalls;
  final bool isLastAssistant;
  final bool isStreaming;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.glass;

    return Theme(
      data: Theme.of(context).copyWith(
        popupMenuTheme: PopupMenuThemeData(
          color: Theme.of(context).colorScheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: tokens.glassBorder, width: 0.8),
          ),
        ),
      ),
      child: PopupMenuButton<String>(
        padding: EdgeInsets.zero,
        iconSize: 15,
        constraints: const BoxConstraints(minWidth: 160),
        icon: Icon(
          Icons.more_horiz_rounded,
          size: 16,
          color: tokens.textSecondary.withValues(alpha: 0.6),
        ),
        onSelected: (action) {
          HapticFeedback.selectionClick();
          switch (action) {
            case 'tools':
              _showToolInspectorSheet(context, toolCalls);
              break;
            case 'copy':
              Clipboard.setData(ClipboardData(text: message.content));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Message copied to clipboard'),
                  duration: Duration(seconds: 1),
                ),
              );
              break;
            case 'regenerate':
              ref.read(chatControllerProvider.notifier).regenerate();
              break;
          }
        },
        itemBuilder: (context) => [
          if (toolCalls.isNotEmpty)
            PopupMenuItem<String>(
              value: 'tools',
              height: 36,
              child: Row(
                children: [
                  Icon(AppIcons.wrench, size: 14, color: tokens.accent),
                  const SizedBox(width: 8),
                  Text(
                    'Inspect Tools (${toolCalls.length})',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: tokens.accent,
                    ),
                  ),
                ],
              ),
            ),
          const PopupMenuItem<String>(
            value: 'copy',
            height: 36,
            child: Row(
              children: [
                Icon(AppIcons.copy, size: 14),
                SizedBox(width: 8),
                Text('Copy Response', style: TextStyle(fontSize: 12)),
              ],
            ),
          ),
          if (isLastAssistant && !isStreaming)
            const PopupMenuItem<String>(
              value: 'regenerate',
              height: 36,
              child: Row(
                children: [
                  Icon(AppIcons.rotateCcw, size: 14),
                  SizedBox(width: 8),
                  Text('Regenerate', style: TextStyle(fontSize: 12)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Opens the Executive Tool Inspector Modal Sheet
void _showToolInspectorSheet(BuildContext context, List<ToolCallInfo> toolCalls) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => _ToolInspectorSheet(toolCalls: toolCalls),
  );
}

/// Executive Glass Bottom Sheet detailing all tool executions (Hermes / OpenClaw style)
class _ToolInspectorSheet extends StatelessWidget {
  const _ToolInspectorSheet({required this.toolCalls});

  final List<ToolCallInfo> toolCalls;

  @override
  Widget build(BuildContext context) {
    final tokens = context.glass;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(20),
        ),
        border: Border(top: BorderSide(color: tokens.glassBorder)),
      ),
      padding: EdgeInsets.fromLTRB(
        20,
        14,
        20,
        16 + MediaQuery.of(context).viewPadding.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: tokens.textSecondary.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: tokens.accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: tokens.accent.withValues(alpha: 0.3),
                    width: 0.8,
                  ),
                ),
                child: Icon(AppIcons.wrench, size: 16, color: tokens.accent),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tool Execution Details',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      '${toolCalls.length} tool${toolCalls.length == 1 ? '' : 's'} executed during this turn',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: tokens.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, size: 20),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Tool calls list
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: toolCalls.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final tool = toolCalls[index];
                final isError = tool.isError ?? false;

                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: tokens.terminalSurface,
                    borderRadius: BorderRadius.circular(tokens.radiusSm),
                    border: Border.all(
                      color: isError
                          ? Colors.redAccent.withValues(alpha: 0.4)
                          : tokens.glassBorder,
                      width: 0.8,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Tool header
                      Row(
                        children: [
                          Icon(
                            isError
                                ? AppIcons.alertCircle
                                : AppIcons.checkCircle2,
                            size: 14,
                            color: isError
                                ? Colors.redAccent
                                : (isDark
                                    ? Colors.tealAccent
                                    : Colors.teal),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              tool.name,
                              style: AppTheme.mono(
                                fontSize: 12.5,
                                fontWeight: FontWeight.bold,
                                color: isDark
                                    ? Colors.white
                                    : theme.colorScheme.onSurface,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: (isError
                                      ? Colors.redAccent
                                      : tokens.accent)
                                  .withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              isError ? 'Error' : 'Executed',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: isError
                                    ? Colors.redAccent
                                    : tokens.accent,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // Arguments
                      if (tool.argumentsJson.isNotEmpty &&
                          tool.argumentsJson != '{}') ...[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'PARAMETERS',
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.6,
                                color: tokens.textSecondary,
                              ),
                            ),
                            InkWell(
                              onTap: () {
                                HapticFeedback.lightImpact();
                                Clipboard.setData(
                                    ClipboardData(text: tool.argumentsJson));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Parameters copied'),
                                    duration: Duration(seconds: 1),
                                  ),
                                );
                              },
                              child: Padding(
                                padding: const EdgeInsets.all(2),
                                child: Text(
                                  'Copy',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: tokens.accent,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: tokens.glassColor,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                                color: tokens.glassBorder, width: 0.6),
                          ),
                          child: SelectableText(
                            tool.argumentsJson,
                            style: AppTheme.mono(
                              fontSize: 11,
                              color: tokens.textSecondary,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                      ],

                      // Result / Output
                      if (tool.result != null && tool.result!.isNotEmpty) ...[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'OUTPUT',
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.6,
                                color: tokens.textSecondary,
                              ),
                            ),
                            InkWell(
                              onTap: () {
                                HapticFeedback.lightImpact();
                                Clipboard.setData(
                                    ClipboardData(text: tool.result!));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Output copied'),
                                    duration: Duration(seconds: 1),
                                  ),
                                );
                              },
                              child: Padding(
                                padding: const EdgeInsets.all(2),
                                child: Text(
                                  'Copy',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: tokens.accent,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Container(
                          width: double.infinity,
                          constraints: const BoxConstraints(maxHeight: 180),
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: tokens.glassColor,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: isError
                                  ? Colors.redAccent.withValues(alpha: 0.3)
                                  : tokens.glassBorder,
                              width: 0.6,
                            ),
                          ),
                          child: SingleChildScrollView(
                            child: SelectableText(
                              tool.result!,
                              style: AppTheme.mono(
                                fontSize: 11,
                                color: isError
                                    ? Colors.redAccent
                                    : Theme.of(context)
                                        .colorScheme
                                        .onSurface,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionIcon extends StatelessWidget {
  const _ActionIcon({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(4),
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Icon(icon, size: 13, color: context.glass.textSecondary),
      ),
    );
  }
}

/// Attachment chips rendered above message text.
class _AttachmentChips extends StatelessWidget {
  const _AttachmentChips({required this.json});

  final String json;

  @override
  Widget build(BuildContext context) {
    final tokens = context.glass;
    List<AttachmentMeta> attachments;
    try {
      attachments = [
        for (final raw in jsonDecode(json) as List)
          AttachmentMeta.fromJson(raw as Map<String, dynamic>),
      ];
    } on FormatException {
      return const SizedBox.shrink();
    }
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final a in attachments)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(tokens.radiusSm),
              border: Border.all(color: tokens.glassBorder),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  a.isImage ? AppIcons.image : AppIcons.file,
                  size: 13,
                  color: tokens.textSecondary,
                ),
                const SizedBox(width: 4),
                Text(a.name, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
      ],
    );
  }
}

/// Thinking state badge with animated pulsing glowing dot.
class _ThinkingState extends StatelessWidget {
  const _ThinkingState({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _PulsingDot(color: color),
          const SizedBox(width: 6),
          Text(
            'Thinking & Reasoning...',
            style: TextStyle(
              fontSize: 12,
              fontStyle: FontStyle.italic,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _PulsingDot extends StatefulWidget {
  const _PulsingDot({required this.color});

  final Color color;

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
      child: Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          color: widget.color,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: widget.color.withValues(alpha: 0.6),
              blurRadius: 6,
              spreadRadius: 1,
            ),
          ],
        ),
      ),
    );
  }
}

/// Minimalist token speed indicator in right bottom corner of assistant message container.
class _SpeedBadge extends StatelessWidget {
  const _SpeedBadge({
    required this.speed,
    required this.isStreaming,
    this.completionTokens,
    required this.tokens,
  });

  final double? speed;
  final bool isStreaming;
  final int? completionTokens;
  final GlassTokens tokens;

  @override
  Widget build(BuildContext context) {
    if (speed == null && !isStreaming && completionTokens == null) {
      return const SizedBox.shrink();
    }

    String label;
    if (speed != null && speed! > 0) {
      label = '${speed!.toStringAsFixed(1)} tok/s';
    } else if (isStreaming) {
      label = 'streaming…';
    } else if (completionTokens != null && completionTokens! > 0) {
      label = '$completionTokens tok';
    } else {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.only(left: 8),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: isStreaming
            ? tokens.accent.withValues(alpha: 0.12)
            : tokens.textSecondary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(tokens.radiusSm),
        border: Border.all(
          color: isStreaming
              ? tokens.accent.withValues(alpha: 0.3)
              : tokens.glassBorder.withValues(alpha: 0.4),
          width: 0.6,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            AppIcons.zap,
            size: 10,
            color: isStreaming ? tokens.accent : tokens.textSecondary,
          ),
          const SizedBox(width: 3),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              fontFamily: 'monospace',
              color: isStreaming ? tokens.accent : tokens.textSecondary,
              letterSpacing: -0.2,
            ),
          ),
        ],
      ),
    );
  }
}



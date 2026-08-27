import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:pocketstrike/app/router.dart';
import 'package:pocketstrike/app/theme/glass_tokens.dart';
import 'package:pocketstrike/core/db/app_database.dart' show Conversation;
import 'package:pocketstrike/shared/widgets/app_icons.dart';
import 'package:pocketstrike/features/conversations/application/conversations_controller.dart';

/// Searchable conversation history, grouped by date, pinned section on top.
class ConversationList extends ConsumerWidget {
  const ConversationList({
    super.key,
    required this.items,
    required this.query,
    required this.currentId,
  });

  final List<Conversation> items;
  final String query;
  final String? currentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.glass;
    final filtered = query.isEmpty
        ? items
        : items
            .where((c) =>
                c.title.toLowerCase().contains(query.toLowerCase()))
            .toList();

    if (filtered.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Text(
            query.isEmpty
                ? 'No conversations yet.\nStart a new chat!'
                : 'No chats match "$query".',
            textAlign: TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: tokens.textSecondary, fontSize: 12),
          ),
        ),
      );
    }

    final pinned = filtered.where((c) => c.pinned).toList();
    final rest = filtered.where((c) => !c.pinned).toList();
    final groups = _groupByDate(rest);

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      children: [
        if (pinned.isNotEmpty) ...[
          const _SectionHeader(label: 'Pinned'),
          for (final c in pinned)
            _ConversationTile(conversation: c, isActive: c.id == currentId),
        ],
        for (final group in groups.entries) ...[
          _SectionHeader(label: group.key),
          for (final c in group.value)
            _ConversationTile(conversation: c, isActive: c.id == currentId),
        ],
      ],
    );
  }

  Map<String, List<Conversation>> _groupByDate(List<Conversation> items) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final groups = <String, List<Conversation>>{};
    for (final c in items) {
      final date = DateTime(
          c.updatedAt.year, c.updatedAt.month, c.updatedAt.day);
      final diff = today.difference(date).inDays;
      final label = diff == 0
          ? 'Today'
          : diff == 1
              ? 'Yesterday'
              : diff < 7
                  ? 'Previous 7 days'
                  : DateFormat.yMMMM().format(c.updatedAt);
      groups.putIfAbsent(label, () => []).add(c);
    }
    return groups;
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 10, 8, 3),
      child: Text(
        label.toUpperCase(),
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: context.glass.textSecondary,
              letterSpacing: 0.8,
              fontWeight: FontWeight.w600,
              fontSize: 10,
            ),
      ),
    );
  }
}

class _ConversationTile extends ConsumerWidget {
  const _ConversationTile({required this.conversation, required this.isActive});

  final Conversation conversation;
  final bool isActive;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.glass;
    final actions = ref.read(conversationActionsProvider);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1.5),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: isActive
              ? tokens.accent.withValues(alpha: 0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(tokens.radiusSm),
          border: isActive
              ? Border.all(
                  color: tokens.accent.withValues(alpha: 0.35), width: 0.8)
              : Border.all(color: Colors.transparent),
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(tokens.radiusSm),
          child: InkWell(
            borderRadius: BorderRadius.circular(tokens.radiusSm),
            onTap: () {
              HapticFeedback.selectionClick();
              ref
                  .read(currentConversationIdProvider.notifier)
                  .state = conversation.id;
              context.go('${AppRoutes.chat}/${conversation.id}');
              Navigator.of(context).maybePop();
            },
            onLongPress: () => _showActions(context, ref, actions),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Row(
                children: [
                  if (conversation.source == 'telegram')
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: Icon(AppIcons.send,
                          size: 13, color: tokens.textSecondary),
                    ),
                  Expanded(
                    child: Text(
                      conversation.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontSize: 12.5,
                            fontWeight:
                                isActive ? FontWeight.w600 : FontWeight.normal,
                            color: isActive
                                ? tokens.accent
                                : Theme.of(context).colorScheme.onSurface,
                          ),
                    ),
                  ),
                  if (conversation.pinned)
                    Icon(AppIcons.pin,
                        size: 13, color: tokens.accent),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showActions(
    BuildContext context,
    WidgetRef ref,
    ConversationActions actions,
  ) {
    HapticFeedback.mediumImpact();
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) {
        final tokens = sheetContext.glass;
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(sheetContext).colorScheme.surface,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(tokens.radiusLg),
            ),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  dense: true,
                  leading: Icon(AppIcons.edit,
                      size: 18, color: tokens.textSecondary),
                  title: const Text('Rename', style: TextStyle(fontSize: 13)),
                  onTap: () async {
                    Navigator.pop(sheetContext);
                    final newTitle = await _promptRename(context);
                    if (newTitle != null && newTitle.isNotEmpty) {
                      await actions.rename(conversation.id, newTitle);
                    }
                  },
                ),
                ListTile(
                  dense: true,
                  leading: Icon(
                    conversation.pinned
                        ? AppIcons.pinOff
                        : AppIcons.pin,
                    size: 18,
                    color: tokens.textSecondary,
                  ),
                  title: Text(conversation.pinned ? 'Unpin' : 'Pin',
                      style: const TextStyle(fontSize: 13)),
                  onTap: () async {
                    Navigator.pop(sheetContext);
                    await actions.togglePin(conversation);
                  },
                ),
                ListTile(
                  dense: true,
                  leading: const Icon(AppIcons.gitBranch, size: 18),
                  title: const Text('Branch conversation',
                      style: TextStyle(fontSize: 13)),
                  onTap: () async {
                    Navigator.pop(sheetContext);
                    final newId = await actions.branch(conversation.id);
                    if (context.mounted) {
                      ref
                          .read(currentConversationIdProvider.notifier)
                          .state = newId;
                      context.go('${AppRoutes.chat}/$newId');
                    }
                  },
                ),
                ListTile(
                  dense: true,
                  leading: const Icon(AppIcons.trash2,
                      size: 18, color: Colors.redAccent),
                  title: const Text('Delete',
                      style: TextStyle(fontSize: 13, color: Colors.redAccent)),
                  onTap: () async {
                    Navigator.pop(sheetContext);
                    await actions.delete(conversation.id);
                    if (context.mounted) context.go(AppRoutes.chat);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<String?> _promptRename(BuildContext context) {
    final controller = TextEditingController(text: conversation.title);
    return showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Rename chat'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Chat title'),
          onSubmitted: (v) => Navigator.pop(dialogContext, v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}

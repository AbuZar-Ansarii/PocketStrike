import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pocketstrike/app/theme/glass_tokens.dart';
import 'package:pocketstrike/shared/widgets/app_icons.dart';
import 'package:pocketstrike/features/conversations/application/conversations_controller.dart';
import 'package:pocketstrike/features/mcp/application/mcp_controller.dart';

/// AppBar icon menu allowing the user to toggle which connected MCP
/// servers supply tools to the current conversation.
class McpToggleMenu extends ConsumerWidget {
  const McpToggleMenu({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.glass;
    final servers = ref.watch(mcpServersProvider).valueOrNull ?? const [];
    final activeId = ref.watch(currentConversationIdProvider);
    final conversation = ref.watch(currentConversationProvider).valueOrNull;

    if (servers.isEmpty || activeId == null) {
      return const SizedBox.shrink();
    }

    final enabledSet = conversation?.enabledMcpServerIds ?? const <String>{};

    return PopupMenuButton<String>(
      tooltip: 'Toggle MCP servers',
      icon: Icon(AppIcons.plug, color: tokens.accent),
      onSelected: (serverId) async {
        final next = Set<String>.from(enabledSet);
        if (next.contains(serverId)) {
          next.remove(serverId);
        } else {
          next.add(serverId);
        }
        await ref
            .read(conversationActionsProvider)
            .updateEnabledMcpServers(activeId, next);
      },
      itemBuilder: (context) => [
        PopupMenuItem<String>(
          enabled: false,
          child: Text(
            'ACTIVE MCP SERVERS',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                ),
          ),
        ),
        for (final server in servers)
          CheckedPopupMenuItem<String>(
            value: server.id,
            checked: enabledSet.contains(server.id),
            child: Text(server.name),
          ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pocketstrike/app/theme/glass_tokens.dart';
import 'package:pocketstrike/shared/widgets/app_icons.dart';
import 'package:pocketstrike/shared/widgets/glass_button.dart';
import 'package:pocketstrike/shared/widgets/status_dot.dart';
import 'package:pocketstrike/features/agent/domain/agent_tool.dart';
import 'package:pocketstrike/features/mcp/application/mcp_controller.dart';
import 'package:pocketstrike/features/mcp/ui/connect_mcp_sheet.dart';
import 'package:pocketstrike/features/mcp/ui/mcp_marketplace_sheet.dart';

class McpSettingsScreen extends ConsumerWidget {
  const McpSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.glass;
    final servers = ref.watch(mcpServersProvider).valueOrNull ?? const [];
    final connections = ref.watch(mcpConnectionsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'MCP Servers',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        actions: [
          IconButton(
            icon: const Icon(AppIcons.sparkles, size: 20),
            tooltip: 'MCP Marketplace',
            onPressed: () => McpMarketplaceSheet.show(context),
          ),
          // Top right corner "+ Connect MCP" action button
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilledButton.icon(
              icon: const Icon(AppIcons.plus, size: 16),
              label: const Text('Connect', style: TextStyle(fontSize: 12)),
              style: FilledButton.styleFrom(
                backgroundColor: tokens.accent,
                foregroundColor: tokens.onAccent,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              onPressed: () => ConnectMcpSheet.show(context),
            ),
          ),
          if (servers.isNotEmpty)
            IconButton(
              icon: const Icon(AppIcons.rotateCcw, size: 18),
              tooltip: 'Reconnect all',
              onPressed: () {
                ref
                    .read(mcpConnectionsProvider.notifier)
                    .connectEnabled();
              },
            ),
        ],
      ),
      body: servers.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(AppIcons.plug,
                        size: 48, color: tokens.textSecondary),
                    const SizedBox(height: 16),
                    Text(
                      'No MCP Servers Connected',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Add Model Context Protocol (MCP) servers to supply live '
                      'external tools, APIs, and data sources to your AI agent.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: tokens.textSecondary),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        GlassButton(
                          label: 'Explore Marketplace',
                          icon: AppIcons.sparkles,
                          onPressed: () => McpMarketplaceSheet.show(context),
                        ),
                        const SizedBox(width: 12),
                        GlassButton(
                          label: 'Custom Server',
                          icon: AppIcons.plus,
                          onPressed: () => ConnectMcpSheet.show(context),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                for (final server in servers) ...[
                  Builder(builder: (context) {
                    final conn = connections[server.id];
                    final tools = conn?.tools ?? const [];
                    final statusState = switch (conn?.status.name) {
                      'connected' => StatusDotState.connected,
                      'connecting' || 'reconnecting' =>
                        StatusDotState.reconnecting,
                      'error' => StatusDotState.error,
                      _ => StatusDotState.idle,
                    };
                    final statusText = switch (conn?.status.name) {
                      'connected' => 'Connected',
                      'connecting' => 'Connecting…',
                      'reconnecting' => 'Reconnecting…',
                      'error' => 'Connection error',
                      _ => 'Offline',
                    };

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: tokens.glassColor,
                        borderRadius: BorderRadius.circular(tokens.radiusSm),
                        border: Border.all(color: tokens.glassBorder),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        borderRadius: BorderRadius.circular(tokens.radiusSm),
                        child: Theme(
                          data: Theme.of(context).copyWith(
                            dividerColor: Colors.transparent,
                          ),
                          child: ExpansionTile(
                            key: PageStorageKey(server.id),
                            leading: StatusDot(state: statusState),
                            title: Text(
                              server.name,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                            ),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(
                                '$statusText • ${tools.length} tool${tools.length == 1 ? "" : "s"}\n${server.url}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: tokens.textSecondary,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(AppIcons.rotateCcw, size: 18),
                                  tooltip: 'Reconnect',
                                  onPressed: () => ref
                                      .read(mcpConnectionsProvider.notifier)
                                      .reconnect(server),
                                ),
                                IconButton(
                                  icon: const Icon(AppIcons.trash2,
                                      color: Colors.redAccent, size: 18),
                                  tooltip: 'Delete',
                                  onPressed: () => ref
                                      .read(mcpActionsProvider)
                                      .deleteServer(server.id),
                                ),
                                const Icon(AppIcons.chevronDown, size: 18),
                              ],
                            ),
                            children: [
                              if (tools.isEmpty)
                                Padding(
                                  padding:
                                      const EdgeInsets.fromLTRB(16, 0, 16, 14),
                                  child: Row(
                                    children: [
                                      Icon(AppIcons.alertCircle,
                                          size: 14,
                                          color: tokens.textSecondary),
                                      const SizedBox(width: 8),
                                      Text(
                                        conn?.status.name == 'error'
                                            ? 'Error: ${conn?.errorMessage ?? "Failed to connect"}'
                                            : 'No tools discovered yet.',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: tokens.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              else
                                Padding(
                                  padding:
                                      const EdgeInsets.fromLTRB(16, 0, 16, 14),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Divider(height: 1),
                                      const SizedBox(height: 10),
                                      Text(
                                        'DISCOVERED TOOLS (${tools.length}):',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(
                                              fontWeight: FontWeight.bold,
                                              letterSpacing: 0.8,
                                              color: tokens.textSecondary,
                                            ),
                                      ),
                                      const SizedBox(height: 8),
                                      for (final tool in tools) ...[
                                        Padding(
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 4),
                                          child: Row(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Padding(
                                                padding: const EdgeInsets.only(
                                                    top: 2),
                                                child: Icon(
                                                  tool.risk == ToolRisk.safe
                                                      ? AppIcons.checkCircle2
                                                      : tool.risk ==
                                                              ToolRisk
                                                                  .destructive
                                                          ? AppIcons.alertCircle
                                                          : AppIcons.wrench,
                                                  size: 15,
                                                  color: tool.risk ==
                                                          ToolRisk.safe
                                                      ? Colors.greenAccent
                                                      : tool.risk ==
                                                              ToolRisk
                                                                  .destructive
                                                          ? Colors.redAccent
                                                          : tokens.accent,
                                                ),
                                              ),
                                              const SizedBox(width: 10),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      tool.name.replaceFirst(
                                                          'mcp__${server.id}__',
                                                          ''),
                                                      style: Theme.of(context)
                                                          .textTheme
                                                          .bodyMedium
                                                          ?.copyWith(
                                                            fontWeight:
                                                                FontWeight.w600,
                                                          ),
                                                    ),
                                                    if (tool.description
                                                        .isNotEmpty)
                                                      Text(
                                                        tool.description,
                                                        style: TextStyle(
                                                          fontSize: 11.5,
                                                          color: tokens
                                                              .textSecondary,
                                                        ),
                                                        maxLines: 2,
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                      ),
                                                  ],
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 6,
                                                        vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: (tool.risk ==
                                                              ToolRisk.safe
                                                          ? Colors.green
                                                          : tool.risk ==
                                                                  ToolRisk
                                                                      .destructive
                                                              ? Colors.red
                                                              : Colors.orange)
                                                      .withValues(alpha: 0.15),
                                                  borderRadius:
                                                      BorderRadius.circular(4),
                                                ),
                                                child: Text(
                                                  tool.risk == ToolRisk.safe
                                                      ? 'AUTO'
                                                      : tool.risk ==
                                                              ToolRisk
                                                                  .destructive
                                                          ? 'DESTRUCTIVE'
                                                          : 'EXTERNAL',
                                                  style: TextStyle(
                                                    fontSize: 9.5,
                                                    fontWeight: FontWeight.bold,
                                                    color: tool.risk ==
                                                            ToolRisk.safe
                                                        ? Colors.greenAccent
                                                        : tool.risk ==
                                                                ToolRisk
                                                                    .destructive
                                                            ? Colors.redAccent
                                                            : Colors.orangeAccent,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        if (tool != tools.last)
                                          const Divider(
                                            height: 8,
                                            indent: 25,
                                            thickness: 0.4,
                                          ),
                                      ],
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                ],
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: GlassButton(
                        label: 'Marketplace',
                        icon: AppIcons.sparkles,
                        onPressed: () => McpMarketplaceSheet.show(context),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: GlassButton(
                        label: 'Connect Custom',
                        icon: AppIcons.plus,
                        onPressed: () => ConnectMcpSheet.show(context),
                      ),
                    ),
                  ],
                ),
              ],
            ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pocketstrike/app/theme/glass_tokens.dart';
import 'package:pocketstrike/shared/widgets/app_icons.dart';
import 'package:pocketstrike/shared/widgets/glass_button.dart';
import 'package:pocketstrike/features/mcp/application/mcp_controller.dart';

class McpMarketplacePreset {
  const McpMarketplacePreset({
    required this.id,
    required this.name,
    required this.description,
    required this.url,
    required this.transport,
    required this.icon,
    required this.category,
    required this.toolCountHint,
  });

  final String id;
  final String name;
  final String description;
  final String url;
  final String transport;
  final IconData icon;
  final String category;
  final String toolCountHint;
}

const mcpMarketplacePresets = <McpMarketplacePreset>[
  McpMarketplacePreset(
    id: 'fastmcp_calc',
    name: 'FastMCP Cloud Calculator',
    description: 'High-speed cloud arithmetic, random numbers, & math expression evaluator.',
    url: 'https://bizarre-gold-antelope.fastmcp.app/mcp',
    transport: 'streamableHttp',
    icon: AppIcons.calculator,
    category: 'System',
    toolCountHint: '2 tools',
  ),
  McpMarketplacePreset(
    id: 'local_pc_suite',
    name: 'Local PC & Hardware Suite',
    description: 'Control PC hardware, filesystem, battery, processes, and Gmail inbox via SSE.',
    url: 'http://10.84.104.59:8000/sse',
    transport: 'sse',
    icon: AppIcons.smartphone,
    category: 'System',
    toolCountHint: '62 tools',
  ),
  McpMarketplacePreset(
    id: 'brave_search',
    name: 'Brave Live Web Search',
    description: 'Real-time global web search, site indexing, & location search API.',
    url: 'https://api.smithery.ai/mcp/v1/brave-search',
    transport: 'streamableHttp',
    icon: AppIcons.globe,
    category: 'Search & News',
    toolCountHint: '3 tools',
  ),
  McpMarketplacePreset(
    id: 'fetch_scraper',
    name: 'Fetch Web Content Scraper',
    description: 'Extract markdown, clean HTML text, and metadata from any public website URL.',
    url: 'https://api.smithery.ai/mcp/v1/fetch',
    transport: 'streamableHttp',
    icon: AppIcons.download,
    category: 'Search & News',
    toolCountHint: '2 tools',
  ),
  McpMarketplacePreset(
    id: 'weather_global',
    name: 'Global Weather Forecast',
    description: 'Live weather, temperature, humidity, wind, and forecast data for any city.',
    url: 'https://api.smithery.ai/mcp/v1/weather',
    transport: 'streamableHttp',
    icon: AppIcons.sparkles,
    category: 'Search & News',
    toolCountHint: '2 tools',
  ),
  McpMarketplacePreset(
    id: 'hackernews',
    name: 'HackerNews Tech Digest',
    description: 'Fetch top developer stories, tech news, comments, & trending discussions.',
    url: 'https://api.smithery.ai/mcp/v1/hackernews',
    transport: 'streamableHttp',
    icon: AppIcons.terminal,
    category: 'Search & News',
    toolCountHint: '4 tools',
  ),
  McpMarketplacePreset(
    id: 'github_explorer',
    name: 'GitHub Code & Repos',
    description: 'Read GitHub repositories, pull requests, code issues, commits, & source files.',
    url: 'https://api.smithery.ai/mcp/v1/github',
    transport: 'streamableHttp',
    icon: AppIcons.folder,
    category: 'Developer',
    toolCountHint: '12 tools',
  ),
  McpMarketplacePreset(
    id: 'puppeteer_browser',
    name: 'Puppeteer Web Automation',
    description: 'Render dynamic JavaScript web pages, capture screenshots, & automate click flows.',
    url: 'https://api.smithery.ai/mcp/v1/puppeteer',
    transport: 'streamableHttp',
    icon: AppIcons.globe,
    category: 'Developer',
    toolCountHint: '6 tools',
  ),
  McpMarketplacePreset(
    id: 'memory_graph',
    name: 'Memory & Knowledge Graph',
    description: 'Persistent memory server to store user facts, context, entities & relationships.',
    url: 'http://localhost:8080/mcp',
    transport: 'streamableHttp',
    icon: AppIcons.brain,
    category: 'Database & Memory',
    toolCountHint: '5 tools',
  ),
  McpMarketplacePreset(
    id: 'postgres_db',
    name: 'PostgreSQL Database MCP',
    description: 'Query SQL tables, inspect schemas, and manage relational database records.',
    url: 'https://api.smithery.ai/mcp/v1/postgres',
    transport: 'streamableHttp',
    icon: AppIcons.wrench,
    category: 'Database & Memory',
    toolCountHint: '8 tools',
  ),
  McpMarketplacePreset(
    id: 'time_clock',
    name: 'Timezone & World Clock',
    description: 'Timezone conversions, ISO timestamps, and international clock calculation.',
    url: 'https://api.smithery.ai/mcp/v1/time',
    transport: 'streamableHttp',
    icon: AppIcons.rotateCcw,
    category: 'System',
    toolCountHint: '2 tools',
  ),
];

class McpMarketplaceSheet extends ConsumerStatefulWidget {
  const McpMarketplaceSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const McpMarketplaceSheet(),
    );
  }

  @override
  ConsumerState<McpMarketplaceSheet> createState() =>
      _McpMarketplaceSheetState();
}

class _McpMarketplaceSheetState extends ConsumerState<McpMarketplaceSheet> {
  String _selectedCategory = 'All';

  final List<String> _categories = [
    'All',
    'System',
    'Search & News',
    'Developer',
    'Database & Memory',
  ];

  @override
  Widget build(BuildContext context) {
    final tokens = context.glass;
    final theme = Theme.of(context);
    final configured = ref.watch(mcpServersProvider).valueOrNull ?? const [];
    final configuredUrls = configured.map((s) => s.url).toSet();

    final filteredPresets = _selectedCategory == 'All'
        ? mcpMarketplacePresets
        : mcpMarketplacePresets
            .where((p) => p.category == _selectedCategory)
            .toList();

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(tokens.radiusLg),
        ),
        border: Border(top: BorderSide(color: tokens.glassBorder)),
      ),
      padding: EdgeInsets.fromLTRB(
        20,
        16,
        20,
        16 + MediaQuery.of(context).viewPadding.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
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
          const SizedBox(height: 16),
          Row(
            children: [
              Icon(AppIcons.sparkles, color: tokens.accent, size: 22),
              const SizedBox(width: 10),
              Text(
                'MCP Server Marketplace',
                style: theme.textTheme.titleLarge,
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: tokens.accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${mcpMarketplacePresets.length} Available',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: tokens.accent,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Explore and connect Model Context Protocol (MCP) servers with 1 tap.',
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: tokens.textSecondary),
          ),
          const SizedBox(height: 14),

          // Category Chips Filter
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final cat in _categories) ...[
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      selected: _selectedCategory == cat,
                      label: Text(cat, style: const TextStyle(fontSize: 12)),
                      selectedColor: tokens.accent.withValues(alpha: 0.2),
                      checkmarkColor: tokens.accent,
                      backgroundColor: tokens.glassColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(
                          color: _selectedCategory == cat
                              ? tokens.accent
                              : tokens.glassBorder,
                        ),
                      ),
                      onSelected: (_) {
                        setState(() => _selectedCategory = cat);
                      },
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),

          Expanded(
            child: ListView.builder(
              itemCount: filteredPresets.length,
              itemBuilder: (context, index) {
                final preset = filteredPresets[index];
                final isAdded = configuredUrls.contains(preset.url);

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: tokens.glassColor,
                    borderRadius: BorderRadius.circular(tokens.radiusSm),
                    border: Border.all(
                      color: isAdded
                          ? tokens.accent.withValues(alpha: 0.4)
                          : tokens.glassBorder,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: tokens.accent.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(preset.icon,
                            color: tokens.accent, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    preset.name,
                                    style: theme.textTheme.titleMedium
                                        ?.copyWith(fontSize: 14.5),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: tokens.accent.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    preset.toolCountHint,
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: tokens.accent,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 3),
                            Text(
                              preset.description,
                              style: theme.textTheme.bodySmall
                                  ?.copyWith(color: tokens.textSecondary),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${preset.transport == "sse" ? "SSE" : "Streamable HTTP"} • ${preset.url}',
                              style: TextStyle(
                                fontSize: 10.5,
                                color: tokens.textSecondary.withValues(alpha: 0.8),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      isAdded
                          ? Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.green.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(AppIcons.checkCircle2,
                                      size: 14, color: Colors.greenAccent),
                                  SizedBox(width: 4),
                                  Text(
                                    'Added',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.greenAccent,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : FilledButton(
                              onPressed: () async {
                                await ref.read(mcpActionsProvider).saveServer(
                                      name: preset.name,
                                      url: preset.url,
                                      transport: preset.transport,
                                    );
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Connected ${preset.name}!'),
                                      duration: const Duration(seconds: 2),
                                    ),
                                  );
                                }
                              },
                              style: FilledButton.styleFrom(
                                backgroundColor: tokens.accent,
                                foregroundColor: tokens.onAccent,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 8),
                                minimumSize: Size.zero,
                                tapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: const Text('Add',
                                  style: TextStyle(fontSize: 12)),
                            ),
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 10),
          GlassButton(
            label: 'Close Marketplace',
            icon: AppIcons.checkCircle2,
            expanded: true,
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }
}

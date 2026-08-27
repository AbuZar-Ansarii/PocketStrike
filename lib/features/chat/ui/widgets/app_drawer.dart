import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pocketstrike/app/router.dart';
import 'package:pocketstrike/app/theme/glass_tokens.dart';
import 'package:pocketstrike/shared/widgets/app_icons.dart';
import 'package:pocketstrike/shared/widgets/app_logo.dart';
import 'package:pocketstrike/features/agent/data/cron_task_store.dart';
import 'package:pocketstrike/features/conversations/application/conversations_controller.dart';
import 'package:pocketstrike/features/gallery/application/gallery_controller.dart';
import 'package:pocketstrike/features/providers/application/providers_controller.dart';
import 'package:pocketstrike/features/mcp/ui/connect_mcp_sheet.dart';
import 'conversation_list.dart';

/// Sidebar: compact new chat pill, searchable grouped history,
/// and a clean, professional AI & MCP & Settings bottom bar.
class AppDrawer extends ConsumerStatefulWidget {
  const AppDrawer({super.key});

  @override
  ConsumerState<AppDrawer> createState() => _AppDrawerState();
}

class _AppDrawerState extends ConsumerState<AppDrawer> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final tokens = context.glass;
    final conversations = ref.watch(conversationsProvider);
    final currentId = ref.watch(currentConversationIdProvider);
    final configs = ref.watch(providerConfigsProvider).valueOrNull ?? const [];
    final activeConfig =
        configs.where((c) => c.isDefault).firstOrNull ?? configs.firstOrNull;
    final activeAiName = activeConfig?.name.isNotEmpty == true
        ? activeConfig!.name
        : (configs.isNotEmpty ? configs.first.name : 'AI Models');
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.sizeOf(context).width;
    const panelWidth = 285.0;

    return Drawer(
      width: screenWidth,
      backgroundColor: Colors.transparent,
      elevation: 0,
      shadowColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      child: Row(
        children: [
          // 1. Sleek & Sharp Sidebar Panel (Solid/Crisp, NO blur on sidebar itself)
          Container(
            width: panelWidth,
            height: double.infinity,
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.black
                  : Theme.of(context).colorScheme.surface,
              border: Border(
                right: BorderSide(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : Colors.black.withValues(alpha: 0.08),
                  width: 1.0,
                ),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.6 : 0.15),
                  blurRadius: 24,
                  offset: const Offset(4, 0),
                ),
              ],
            ),
            child: SafeArea(
              child: Column(
                children: [
                  // ---- 1. Header + Phone-in-Hand Badge + Compact New Chat Pill ----
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
                    child: Row(
                      children: [
                        // Cool Phone-in-Hand Glass Badge
                        Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            color: tokens.accent.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(9),
                            border: Border.all(
                              color: tokens.accent.withValues(alpha: 0.4),
                              width: 0.8,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: tokens.accent.withValues(alpha: 0.2),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Center(
                            child: AppLogo(
                              size: 20,
                              color: tokens.accent,
                              eyeColor: isDark ? Colors.black : Colors.white,
                              showGlow: false,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'PocketStrike',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                letterSpacing: -0.2,
                              ),
                        ),
                        const Spacer(),

                        // Compact Sleek "New Chat" Pill Button
                        Material(
                          color: tokens.accent.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(16),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () {
                              HapticFeedback.lightImpact();
                              ref
                                  .read(currentConversationIdProvider.notifier)
                                  .state = null;
                              context.go(AppRoutes.chat);
                              Navigator.of(context).maybePop();
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                    color: tokens.accent
                                        .withValues(alpha: 0.35),
                                    width: 0.8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(AppIcons.plus,
                                      size: 13, color: tokens.accent),
                                  const SizedBox(width: 4),
                                  Text(
                                    'New',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: tokens.accent,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),

                  // ---- Dedicated Reminders & Scheduled Tasks Bar (Above Search Chats) ----
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
                    child: Material(
                      color: tokens.glassColor,
                      borderRadius: BorderRadius.circular(tokens.radiusSm),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(tokens.radiusSm),
                        onTap: () {
                          Navigator.of(context).maybePop();
                          context.push(AppRoutes.settingsTasks);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(tokens.radiusSm),
                            border: Border.all(color: tokens.glassBorder, width: 0.8),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.alarm_on, size: 16, color: tokens.accent),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Tasks & Reminders',
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w600,
                                      ),
                                ),
                              ),
                              Consumer(
                                builder: (context, ref, _) {
                                  final tasks = ref.watch(cronTaskProvider);
                                  final taskCount = tasks.length;
                                  return Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: tokens.accent.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                          color: tokens.accent
                                              .withValues(alpha: 0.4)),
                                    ),
                                    child: Text(
                                      '$taskCount Tasks',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: tokens.accent,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                  // ---- Dedicated AI Image Gallery Bar (Below Tasks & Reminders) ----
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
                    child: Material(
                      color: tokens.glassColor,
                      borderRadius: BorderRadius.circular(tokens.radiusSm),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(tokens.radiusSm),
                        onTap: () {
                          Navigator.of(context).maybePop();
                          context.push(AppRoutes.gallery);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(tokens.radiusSm),
                            border: Border.all(color: tokens.glassBorder, width: 0.8),
                          ),
                          child: Row(
                            children: [
                              Icon(AppIcons.image, size: 16, color: tokens.accent),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'AI Image Gallery',
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w600,
                                      ),
                                ),
                              ),
                              Consumer(
                                builder: (context, ref, _) {
                                  final images = ref.watch(galleryImagesProvider);
                                  final count = images.valueOrNull?.length ?? 0;
                                  return Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: tokens.accent.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                          color: tokens.accent
                                              .withValues(alpha: 0.4)),
                                    ),
                                    child: Text(
                                      '$count Img',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: tokens.accent,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),

                  // ---- 2. Search Chat Section ----
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: SizedBox(
                      height: 34,
                      child: TextField(
                        onChanged: (v) => setState(() => _query = v),
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(fontSize: 12),
                        decoration: InputDecoration(
                          hintText: 'Search chats',
                          hintStyle: TextStyle(
                              color: tokens.textSecondary, fontSize: 11.5),
                          prefixIcon: Icon(AppIcons.search,
                              size: 14, color: tokens.textSecondary),
                          contentPadding:
                              const EdgeInsets.symmetric(vertical: 6),
                          isDense: true,
                          filled: true,
                          fillColor: tokens.glassColor,
                          border: OutlineInputBorder(
                            borderRadius:
                                BorderRadius.circular(tokens.radiusSm),
                            borderSide: BorderSide(
                                color: tokens.glassBorder, width: 0.8),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius:
                                BorderRadius.circular(tokens.radiusSm),
                            borderSide: BorderSide(
                                color: tokens.glassBorder, width: 0.8),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // ---- 3. History List (scrollable) ----
                  Expanded(
                    child: conversations.when(
                      data: (items) => ConversationList(
                        items: items,
                        query: _query,
                        currentId: currentId,
                      ),
                      loading: () =>
                          const Center(child: CircularProgressIndicator()),
                      error: (e, _) => Center(child: Text('Error: $e')),
                    ),
                  ),

                  // ---- 4. Clean & Professional MCP & Settings Bottom Bar ----
                  Container(
                    decoration: BoxDecoration(
                      color: isDark ? Colors.black : tokens.glassColor,
                      border: Border(
                        top: BorderSide(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.08)
                              : tokens.glassBorder,
                          width: 0.8,
                        ),
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(AppIcons.plug, size: 14, color: tokens.accent),
                            const SizedBox(width: 6),
                            Text(
                              'MCP SERVERS',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.8,
                                    color: Theme.of(context).colorScheme.onSurface,
                                  ),
                            ),
                            const Spacer(),
                            GestureDetector(
                              onTap: () {
                                Navigator.of(context).maybePop();
                                context.push(AppRoutes.settingsMcp);
                              },
                              child: Text(
                                'Manage',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w600,
                                  color: tokens.accent,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            // 1. Connected AI Provider Button
                            Expanded(
                              child: SizedBox(
                                height: 32,
                                child: OutlinedButton.icon(
                                  icon: Icon(AppIcons.cpu,
                                      size: 13, color: tokens.accent),
                                  label: Text(
                                    activeAiName,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: Theme.of(context).colorScheme.onSurface,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    backgroundColor: tokens.glassColor,
                                    foregroundColor: Theme.of(context).colorScheme.onSurface,
                                    side: BorderSide(
                                        color: tokens.accent.withValues(alpha: 0.4),
                                        width: 0.8),
                                    shape: RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius.circular(tokens.radiusSm),
                                    ),
                                    padding: const EdgeInsets.symmetric(horizontal: 6),
                                  ),
                                  onPressed: () {
                                    Navigator.of(context).maybePop();
                                    context.push(AppRoutes.settingsProviders);
                                  },
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),

                            // 2. Connect Custom MCP Button
                            Expanded(
                              child: SizedBox(
                                height: 32,
                                child: OutlinedButton.icon(
                                  icon: Icon(AppIcons.plus, size: 13, color: tokens.accent),
                                  label: Text(
                                    'Connect',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: Theme.of(context).colorScheme.onSurface,
                                    ),
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    backgroundColor: tokens.glassColor,
                                    foregroundColor: Theme.of(context).colorScheme.onSurface,
                                    side: BorderSide(
                                        color: tokens.accent.withValues(alpha: 0.4),
                                        width: 0.8),
                                    shape: RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius.circular(tokens.radiusSm),
                                    ),
                                    padding: const EdgeInsets.symmetric(horizontal: 6),
                                  ),
                                  onPressed: () {
                                    Navigator.of(context).maybePop();
                                    ConnectMcpSheet.show(context);
                                  },
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),

                             // 3. Settings Gear Icon Button
                            Material(
                              color: tokens.glassColor,
                              borderRadius: BorderRadius.circular(tokens.radiusSm),
                              child: InkWell(
                                borderRadius:
                                    BorderRadius.circular(tokens.radiusSm),
                                onTap: () {
                                  Navigator.of(context).maybePop();
                                  context.push(AppRoutes.settings);
                                },
                                child: Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    borderRadius:
                                        BorderRadius.circular(tokens.radiusSm),
                                    border: Border.all(
                                        color: tokens.accent.withValues(alpha: 0.4), width: 0.8),
                                  ),
                                  child: Icon(AppIcons.settings,
                                      size: 15, color: Theme.of(context).colorScheme.onSurface),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

    // 2. Right Side Frosted Glass Blur Area ONLY (strictly clipped to right side)
    Expanded(
      child: ClipRect(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            HapticFeedback.lightImpact();
            Navigator.of(context).pop();
          },
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18.0, sigmaY: 18.0),
            child: Container(
              color: Colors.black.withValues(alpha: isDark ? 0.50 : 0.28),
            ),
          ),
        ),
      ),
    ),
  ],
),
);
  }
}

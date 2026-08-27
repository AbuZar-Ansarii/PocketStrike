import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pocketstrike/app/theme/glass_tokens.dart';
import 'package:pocketstrike/core/db/app_database.dart';
import 'package:pocketstrike/shared/widgets/app_icons.dart';
import 'package:pocketstrike/shared/widgets/app_logo.dart';
import 'package:pocketstrike/shared/widgets/glass_button.dart';
import 'package:url_launcher/url_launcher.dart';

class AboutExportScreen extends ConsumerWidget {
  const AboutExportScreen({super.key});

  Future<void> _exportData(BuildContext context, WidgetRef ref) async {
    final db = ref.read(appDatabaseProvider);
    final conversations = await db.conversationsDao.getAll();

    final exportList = <Map<String, dynamic>>[];
    for (final conv in conversations) {
      final messages = await db.messagesDao.getForConversation(conv.id);
      exportList.add({
        'conversation': {
          'id': conv.id,
          'title': conv.title,
          'personaId': conv.personaId,
          'createdAt': conv.createdAt.toIso8601String(),
          'updatedAt': conv.updatedAt.toIso8601String(),
        },
        'messages': messages
            .map((m) => {
                  'id': m.id,
                  'role': m.role,
                  'content': m.content,
                  'toolName': m.toolName,
                  'createdAt': m.createdAt.toIso8601String(),
                })
            .toList(),
      });
    }

    final jsonStr = const JsonEncoder.withIndent('  ').convert(exportList);
    await Clipboard.setData(ClipboardData(text: jsonStr));

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Exported ${conversations.length} conversations to clipboard (JSON)!'),
        ),
      );
    }
  }

  Future<void> _wipeData(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Wipe All App Data?'),
        content: const Text(
          'This will permanently delete all chat conversations, messages, '
          'and local preferences. API keys in Keystore will remain intact.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Wipe Everything'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final db = ref.read(appDatabaseProvider);
      await db.customStatement('DELETE FROM messages;');
      await db.customStatement('DELETE FROM conversations;');

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('All chat history wiped cleanly.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.glass;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Data & About',
          style: Theme.of(context).textTheme.titleMedium,
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // App Phone-in-Hand Logo & Info
          Center(
            child: Column(
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: tokens.accent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: tokens.accent.withValues(alpha: 0.4),
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: tokens.accent.withValues(alpha: 0.25),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Center(
                    child: AppLogo(
                      size: 44,
                      color: tokens.accent,
                      eyeColor: Theme.of(context).brightness == Brightness.dark
                          ? Colors.black
                          : Colors.white,
                      showGlow: true,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text('PocketStrike',
                    style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 4),
                Text('Version 1.0.0 (Build 1)',
                    style: TextStyle(color: tokens.textSecondary)),
                const SizedBox(height: 6),
                Text(
                  'Multi-Provider AI Agent Client with MCP & Storage Bridge',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: tokens.textSecondary, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          Text(
            'DEVELOPER & LINKS',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                  color: tokens.textSecondary,
                ),
          ),
          const SizedBox(height: 10),

          // Built by Mohd Abuzar Creator Card
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: tokens.glassColor,
              borderRadius: BorderRadius.circular(tokens.radiusSm),
              border: Border.all(color: tokens.glassBorder, width: 0.8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: tokens.accent.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: tokens.accent.withValues(alpha: 0.35),
                          width: 0.8,
                        ),
                      ),
                      child: Center(
                        child: Icon(
                          Icons.person_rounded,
                          color: tokens.accent,
                          size: 20,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Built by Mohd Abuzar',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'PocketStrike AI Assistant & Workstation',
                            style: TextStyle(
                              fontSize: 11.5,
                              color: tokens.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // GitHub Profile Link Button
                InkWell(
                  borderRadius: BorderRadius.circular(tokens.radiusSm),
                  onTap: () => _openUrl(context, 'https://github.com/AbuZar-Ansarii'),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: tokens.accent.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(tokens.radiusSm),
                      border: Border.all(
                        color: tokens.accent.withValues(alpha: 0.25),
                        width: 0.8,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.code_rounded,
                          size: 18,
                          color: tokens.accent,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'GitHub Profile',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                'https://github.com/AbuZar-Ansarii',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: tokens.textSecondary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          AppIcons.chevronRight,
                          size: 14,
                          color: tokens.textSecondary,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),

                // YouTube Channel Link Button
                InkWell(
                  borderRadius: BorderRadius.circular(tokens.radiusSm),
                  onTap: () => _openUrl(
                      context, 'https://www.youtube.com/@thevoidkernel'),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF0000).withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(tokens.radiusSm),
                      border: Border.all(
                        color: const Color(0xFFFF0000).withValues(alpha: 0.3),
                        width: 0.8,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 22,
                          height: 16,
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF0000),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.play_arrow_rounded,
                              size: 12,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Thevoidkernel youtube',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                'https://www.youtube.com/@thevoidkernel',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: tokens.textSecondary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          AppIcons.chevronRight,
                          size: 14,
                          color: tokens.textSecondary,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          Text(
            'DATA MANAGEMENT',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                  color: tokens.textSecondary,
                ),
          ),
          const SizedBox(height: 10),

          GlassButton(
            label: 'Export Chat History (JSON)',
            icon: AppIcons.download,
            expanded: true,
            onPressed: () => _exportData(context, ref),
          ),
          const SizedBox(height: 12),

          OutlinedButton.icon(
            icon: const Icon(AppIcons.trash2, color: Colors.redAccent),
            label: const Text('Wipe All Local Data',
                style: TextStyle(color: Colors.redAccent)),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              side: const BorderSide(color: Colors.redAccent),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(tokens.radiusSm),
              ),
            ),
            onPressed: () => _wipeData(context, ref),
          ),
        ],
      ),
    );
  }

  Future<void> _openUrl(BuildContext context, String urlString) async {
    final uri = Uri.parse(urlString);
    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched) {
        final fallbackLaunched = await launchUrl(
          uri,
          mode: LaunchMode.platformDefault,
        );
        if (!fallbackLaunched && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not open $urlString')),
          );
        }
      }
    } catch (e) {
      try {
        await launchUrl(uri);
      } catch (err) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error opening link: $err')),
          );
        }
      }
    }
  }
}

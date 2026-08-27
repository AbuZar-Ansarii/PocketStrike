import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pocketstrike/app/router.dart';
import 'package:pocketstrike/app/theme/glass_tokens.dart';
import 'package:pocketstrike/app/theme/theme_controller.dart';
import 'package:pocketstrike/shared/widgets/app_icons.dart';
import 'package:pocketstrike/features/settings/ui/personas_sheet.dart';
import 'package:url_launcher/url_launcher.dart';

/// Main settings menu grouping all app configurations into sleek glass tiles.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Settings',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        children: [
          const _SectionHeader(title: 'AI & ENGINE'),
          _SettingsTile(
            icon: AppIcons.download,
            title: 'Local & Offline Models',
            subtitle: 'Import GGUF LLMs, image models & load to RAM',
            onTap: () => context.push(AppRoutes.settingsLocalModels),
          ),
          _SettingsTile(
            icon: AppIcons.cpu,
            title: 'AI Providers',
            subtitle: 'OpenAI, Claude, Gemini, Groq, Ollama keys',
            onTap: () => context.push(AppRoutes.settingsProviders),
          ),
          _SettingsTile(
            icon: AppIcons.brain,
            title: 'System Personas',
            subtitle: 'General, Coding, Research & custom AI personas',
            onTap: () => PersonasSheet.show(context),
          ),
          _SettingsTile(
            icon: AppIcons.sparkles,
            title: 'Hermes Self-Evolving Agent',
            subtitle: 'USER.md, MEMORY.md, SOUL.md & adaptive persona',
            onTap: () => context.push(AppRoutes.settingsHermes),
          ),
          _SettingsTile(
            icon: AppIcons.sliders,
            title: 'Model & Parameters',
            subtitle: 'Temperature, top_p, max tokens, system prompt',
            onTap: () => context.push(AppRoutes.settingsModels),
          ),
          _SettingsTile(
            icon: AppIcons.plug,
            title: 'MCP Servers',
            subtitle: 'Model Context Protocol servers & safety rules',
            onTap: () => context.push(AppRoutes.settingsMcp),
          ),
          _SettingsTile(
            icon: AppIcons.wrench,
            title: 'Agent Tools & Capabilities',
            subtitle: 'Filesystem, web search, calculator, code sandbox',
            onTap: () => context.push('/settings/tools'),
          ),

          const SizedBox(height: 12),
          const _SectionHeader(title: 'INTEGRATIONS & STORAGE'),
          _SettingsTile(
            icon: AppIcons.send,
            title: 'Telegram Bridge',
            subtitle: 'Bot token & allowed Chat ID relay',
            onTap: () => context.push('/settings/telegram'),
          ),
          _SettingsTile(
            icon: AppIcons.folder,
            title: 'Storage & Permissions',
            subtitle: 'SAF root folders & safety confirmation policy',
            onTap: () => context.push('/settings/storage'),
          ),
          _SettingsTile(
            icon: AppIcons.brain,
            title: 'Memory & Context',
            subtitle: 'Context window turns size & local RAG store',
            onTap: () => context.push('/settings/memory'),
          ),
          _SettingsTile(
            icon: AppIcons.sparkles,
            title: 'Scheduled Tasks & Cron Jobs',
            subtitle: 'Active reminders, recurring cron tasks & background automation',
            onTap: () => context.push(AppRoutes.settingsTasks),
          ),

          const SizedBox(height: 12),
          const _SectionHeader(title: 'PREFERENCES & SYSTEM'),
          // Single-line 3-button Theme Selector (Dark / Light / System)
          const _ThemeModeRow(),
          const SizedBox(height: 2),

          _SettingsTile(
            icon: AppIcons.phoneInHand,
            title: 'Data & About',
            subtitle: 'Built by Mohd Abuzar · Export chat history or wipe data',
            onTap: () => context.push('/settings/about'),
          ),

          const SizedBox(height: 12),
          const _SectionHeader(title: 'COMMUNITY & DEVELOPER'),
          _SettingsTile(
            customLeading: const _YouTubeLogo(),
            title: 'Thevoidkernel youtube',
            subtitle: 'https://www.youtube.com/@thevoidkernel',
            onTap: () =>
                _openUrl(context, 'https://www.youtube.com/@thevoidkernel'),
          ),
          _SettingsTile(
            customLeading: const _GitHubLogo(),
            title: 'Built by Mohd Abuzar',
            subtitle: 'https://github.com/AbuZar-Ansarii',
            onTap: () =>
                _openUrl(context, 'https://github.com/AbuZar-Ansarii'),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

/// Single-line 3-button theme selector: Dark / Light / System.
class _ThemeModeRow extends ConsumerWidget {
  const _ThemeModeRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.glass;
    final currentMode = ref.watch(themeModeProvider);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: tokens.glassColor,
        borderRadius: BorderRadius.circular(tokens.radiusSm),
        border: Border.all(color: tokens.glassBorder, width: 0.8),
      ),
      child: Row(
        children: [
          _buildThemeBtn(
            context,
            ref,
            label: 'Dark',
            icon: AppIcons.moon,
            mode: ThemeMode.dark,
            currentMode: currentMode,
          ),
          const SizedBox(width: 4),
          _buildThemeBtn(
            context,
            ref,
            label: 'Light',
            icon: AppIcons.sun,
            mode: ThemeMode.light,
            currentMode: currentMode,
          ),
          const SizedBox(width: 4),
          _buildThemeBtn(
            context,
            ref,
            label: 'System',
            icon: AppIcons.smartphone,
            mode: ThemeMode.system,
            currentMode: currentMode,
          ),
        ],
      ),
    );
  }

  Widget _buildThemeBtn(
    BuildContext context,
    WidgetRef ref, {
    required String label,
    required IconData icon,
    required ThemeMode mode,
    required ThemeMode currentMode,
  }) {
    final tokens = context.glass;
    final isSelected = currentMode == mode;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          ref.read(themeModeProvider.notifier).setMode(mode);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          height: 36,
          decoration: BoxDecoration(
            color: isSelected
                ? tokens.accent.withValues(alpha: 0.2)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(tokens.radiusSm - 2),
            border: Border.all(
              color: isSelected
                  ? tokens.accent.withValues(alpha: 0.45)
                  : Colors.transparent,
              width: 0.8,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 14,
                color: isSelected ? tokens.accent : tokens.textSecondary,
              ),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected ? tokens.accent : tokens.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 8, 6, 4),
      child: Text(
        title,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.bold,
              letterSpacing: 0.9,
              fontSize: 10.5,
              color: context.glass.textSecondary,
            ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    this.icon,
    this.customLeading,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData? icon;
  final Widget? customLeading;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.glass;

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: tokens.glassColor,
        borderRadius: BorderRadius.circular(tokens.radiusSm),
        child: InkWell(
          borderRadius: BorderRadius.circular(tokens.radiusSm),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(tokens.radiusSm),
              border: Border.all(color: tokens.glassBorder, width: 0.8),
            ),
            child: Row(
              children: [
                if (customLeading != null)
                  customLeading!
                else
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: tokens.accent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: tokens.accent.withValues(alpha: 0.25),
                        width: 0.8,
                      ),
                    ),
                    child: Icon(icon, color: tokens.accent, size: 16),
                  ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              fontSize: 11.5,
                              color: tokens.textSecondary,
                            ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  AppIcons.chevronRight,
                  size: 14,
                  color: tokens.textSecondary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _YouTubeLogo extends StatelessWidget {
  const _YouTubeLogo();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: const Color(0xFFFF0000).withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: const Color(0xFFFF0000).withValues(alpha: 0.35),
          width: 0.8,
        ),
      ),
      child: Center(
        child: Container(
          width: 18,
          height: 13,
          decoration: BoxDecoration(
            color: const Color(0xFFFF0000),
            borderRadius: BorderRadius.circular(3),
          ),
          child: const Center(
            child: Icon(
              Icons.play_arrow_rounded,
              size: 10,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}

class _GitHubLogo extends StatelessWidget {
  const _GitHubLogo();

  @override
  Widget build(BuildContext context) {
    final tokens = context.glass;
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: tokens.accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: tokens.accent.withValues(alpha: 0.25),
          width: 0.8,
        ),
      ),
      child: Center(
        child: Icon(
          Icons.code_rounded,
          color: tokens.accent,
          size: 16,
        ),
      ),
    );
  }
}

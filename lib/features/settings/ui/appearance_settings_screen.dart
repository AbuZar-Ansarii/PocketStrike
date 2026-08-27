import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pocketstrike/app/theme/glass_tokens.dart';
import 'package:pocketstrike/app/theme/theme_controller.dart';
import 'package:pocketstrike/shared/widgets/app_icons.dart';

/// Screen allowing the user to select Dark, Light, or System mode.
class AppearanceSettingsScreen extends ConsumerWidget {
  const AppearanceSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);
    final tokens = context.glass;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Appearance',
          style: Theme.of(context).textTheme.titleMedium,
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'THEME MODE',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                  color: tokens.textSecondary,
                ),
          ),
          const SizedBox(height: 8),
          _ThemeTile(
            title: 'Dark Mode (Default)',
            subtitle: 'Pure OLED black (#000000), crisp white glass & accents',
            icon: AppIcons.moon,
            selected: mode == ThemeMode.dark,
            onTap: () => ref
                .read(themeModeProvider.notifier)
                .setMode(ThemeMode.dark),
          ),
          _ThemeTile(
            title: 'Light Mode',
            subtitle: 'Soft white base (#FAFAFC), vibrant blue accent',
            icon: AppIcons.sun,
            selected: mode == ThemeMode.light,
            onTap: () => ref
                .read(themeModeProvider.notifier)
                .setMode(ThemeMode.light),
          ),
          _ThemeTile(
            title: 'System Default',
            subtitle: 'Follow your device system theme settings',
            icon: AppIcons.smartphone,
            selected: mode == ThemeMode.system,
            onTap: () => ref
                .read(themeModeProvider.notifier)
                .setMode(ThemeMode.system),
          ),
        ],
      ),
    );
  }
}

class _ThemeTile extends StatelessWidget {
  const _ThemeTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.glass;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: selected
            ? tokens.accent.withValues(alpha: 0.12)
            : tokens.glassColor,
        borderRadius: BorderRadius.circular(tokens.radiusSm),
        border: Border.all(
          color: selected ? tokens.accent : tokens.glassBorder,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(tokens.radiusSm),
        child: ListTile(
          leading: Icon(icon, color: selected ? tokens.accent : tokens.textSecondary),
          title: Text(title, style: Theme.of(context).textTheme.titleMedium),
          subtitle: Text(subtitle, style: TextStyle(color: tokens.textSecondary)),
          trailing: selected
              ? Icon(AppIcons.checkCircle2, color: tokens.accent)
              : null,
          onTap: onTap,
        ),
      ),
    );
  }
}

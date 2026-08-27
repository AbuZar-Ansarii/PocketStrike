import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pocketstrike/features/agent/data/cron_task_store.dart';
import 'package:pocketstrike/features/telegram/telegram_service.dart';
import 'router.dart';
import 'theme/app_theme.dart';
import 'theme/theme_controller.dart';

/// Root widget: animated glass theme + router.
class PocketStrikeApp extends ConsumerWidget {
  const PocketStrikeApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    final themeMode = ref.watch(themeModeProvider);
    // Eagerly initialize cron task background engine & Telegram bridge on app startup
    ref.watch(cronTaskProvider);
    ref.watch(telegramServiceProvider);

    return _AnimatedThemeBuilder(
      themeMode: themeMode,
      builder: (context, light, dark) {
        return MaterialApp.router(
          title: 'PocketStrike',
          debugShowCheckedModeBanner: false,
          theme: light,
          darkTheme: dark,
          themeMode: themeMode,
          routerConfig: router,
        );
      },
    );
  }
}

/// Smoothly lerps both ThemeData objects when the mode changes.
class _AnimatedThemeBuilder extends StatefulWidget {
  const _AnimatedThemeBuilder({
    required this.themeMode,
    required this.builder,
  });

  final ThemeMode themeMode;
  final Widget Function(
    BuildContext context,
    ThemeData light,
    ThemeData dark,
  ) builder;

  @override
  State<_AnimatedThemeBuilder> createState() => _AnimatedThemeBuilderState();
}

class _AnimatedThemeBuilderState extends State<_AnimatedThemeBuilder>
    with SingleTickerProviderStateMixin {
  ThemeData _light = AppTheme.light();
  ThemeData _dark = AppTheme.dark();

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
      tween: Tween(begin: 0, end: 1),
      onEnd: () {
        _light = AppTheme.light();
        _dark = AppTheme.dark();
      },
      builder: (context, t, _) {
        final light = ThemeData.lerp(_light, AppTheme.light(), t);
        final dark = ThemeData.lerp(_dark, AppTheme.dark(), t);
        return widget.builder(context, light, dark);
      },
    );
  }
}

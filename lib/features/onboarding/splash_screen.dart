import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:pocketstrike/shared/widgets/app_logo.dart';

import '../../app/router.dart';
import '../../app/theme/glass_tokens.dart';

/// Branded splash shown briefly at launch (redirects via router).
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 900), () {
      if (mounted) context.go(AppRoutes.chat);
    });
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.glass;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: tokens.glassColor,
                borderRadius: BorderRadius.circular(tokens.radiusLg),
                border: Border.all(color: tokens.glassBorder),
                boxShadow: tokens.softShadow,
              ),
              child: Center(
                child: AppLogo(
                  size: 56,
                  color: tokens.accent,
                  eyeColor: isDark ? Colors.black : Colors.white,
                  showGlow: true,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'PocketStrike',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 6),
            Text(
              'Your pocket AI agent',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: tokens.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

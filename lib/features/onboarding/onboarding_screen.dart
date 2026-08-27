import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pocketstrike/app/router.dart';
import 'package:pocketstrike/app/theme/glass_tokens.dart';
import 'package:pocketstrike/core/storage/prefs_provider.dart';
import 'package:pocketstrike/shared/widgets/app_icons.dart';
import 'package:pocketstrike/shared/widgets/app_logo.dart';
import 'package:pocketstrike/shared/widgets/glass_button.dart';

/// First-run onboarding carousel.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _controller = PageController();
  int _page = 0;

  static const _slides = [
    (
      icon: AppIcons.messageSquare,
      title: 'Chat with any AI',
      body: 'OpenAI, Claude, Gemini, Groq, OpenRouter, Ollama — '
          'or your own endpoint. Streaming, markdown, code highlighting.',
    ),
    (
      icon: AppIcons.bot,
      title: 'Agent mode',
      body: 'Let the model plan and act: it calls tools step by step '
          'while you watch a live timeline — with confirmations for '
          'risky actions.',
    ),
    (
      icon: AppIcons.plug,
      title: 'Connect MCP servers',
      body: 'Plug into Model Context Protocol servers and their tools '
          'merge straight into your agent.',
    ),
    (
      icon: AppIcons.shieldCheck,
      title: 'Private by design',
      body: 'API keys live in the device keystore, chats stay on-device, '
          'and destructive actions always need your approval first.',
    ),
  ];

  Future<void> _finish() async {
    await ref.read(sharedPreferencesProvider).setBool('onboarding_done', true);
    if (mounted) context.go(AppRoutes.chat);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.glass;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _finish,
                child: Text(
                  'Skip',
                  style: TextStyle(color: tokens.textSecondary),
                ),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _slides.length,
                onPageChanged: (i) => setState(() => _page = i),
                itemBuilder: (context, i) {
                  final slide = _slides[i];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 96,
                          height: 96,
                          decoration: BoxDecoration(
                            color: tokens.glassColor,
                            borderRadius:
                                BorderRadius.circular(tokens.radiusLg),
                            border: Border.all(color: tokens.glassBorder),
                            boxShadow: tokens.softShadow,
                          ),
                          child: slide.icon == AppIcons.bot
                              ? Center(
                                  child: AppLogo(
                                    size: 58,
                                    color: tokens.accent,
                                    eyeColor: Theme.of(context).brightness == Brightness.dark
                                        ? Colors.black
                                        : Colors.white,
                                    showGlow: true,
                                  ),
                                )
                              : Icon(slide.icon,
                                  size: 44, color: tokens.accent),
                        ),
                        const SizedBox(height: 28),
                        Text(
                          slide.title,
                          style: Theme.of(context).textTheme.headlineSmall,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          slide.body,
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(color: tokens.textSecondary),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < _slides.length; i++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: i == _page ? 22 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: i == _page
                          ? tokens.accent
                          : tokens.textSecondary.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: GlassButton(
                label: _page == _slides.length - 1 ? 'Get started' : 'Next',
                expanded: true,
                onPressed: () {
                  if (_page == _slides.length - 1) {
                    _finish();
                  } else {
                    _controller.nextPage(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOut,
                    );
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

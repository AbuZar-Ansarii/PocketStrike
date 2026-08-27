import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pocketstrike/app/router.dart';
import 'package:pocketstrike/app/theme/glass_tokens.dart';
import 'package:pocketstrike/shared/widgets/app_icons.dart';
import 'package:pocketstrike/shared/widgets/glass_button.dart';
import 'package:pocketstrike/shared/widgets/status_dot.dart';
import 'package:pocketstrike/features/providers/application/providers_controller.dart';

class ProvidersSettingsScreen extends ConsumerWidget {
  const ProvidersSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.glass;
    final configs = ref.watch(providerConfigsProvider).valueOrNull ?? const [];

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'AI Providers',
          style: Theme.of(context).textTheme.titleMedium,
        ),
      ),
      body: configs.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(AppIcons.key,
                        size: 48, color: tokens.textSecondary),
                    const SizedBox(height: 16),
                    Text(
                      'No AI Providers Configured',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Add an OpenAI, Anthropic Claude, Gemini, Groq, OpenRouter, '
                      'or Ollama provider key to start chatting.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: tokens.textSecondary),
                    ),
                    const SizedBox(height: 24),
                    GlassButton(
                      label: 'Add AI Provider',
                      icon: AppIcons.plus,
                      onPressed: () => context.push(AppRoutes.settingsProviderEdit),
                    ),
                  ],
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                for (final config in configs)
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: tokens.glassColor,
                      borderRadius: BorderRadius.circular(tokens.radiusSm),
                      border: Border.all(
                        color: config.isDefault
                            ? tokens.accent
                            : tokens.glassBorder,
                      ),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(tokens.radiusSm),
                      child: ListTile(
                        leading: StatusDot(
                          state: config.hasKey
                              ? StatusDotState.connected
                              : StatusDotState.idle,
                        ),
                        title: Row(
                          children: [
                            Text(config.name,
                                style: Theme.of(context).textTheme.titleMedium),
                            if (config.isDefault) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: tokens.accent.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  'DEFAULT',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: tokens.accent,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        subtitle: Text(
                          'Model: ${config.defaultModel.isEmpty ? "Provider default" : config.defaultModel}',
                          style: TextStyle(color: tokens.textSecondary),
                        ),
                        trailing: PopupMenuButton<String>(
                          onSelected: (val) async {
                            if (val == 'edit') {
                              context.push(AppRoutes.settingsProviderEdit,
                                  extra: config.id);
                            } else if (val == 'make_default') {
                              await ref
                                  .read(providerActionsProvider)
                                  .setDefault(config.id);
                            } else if (val == 'delete') {
                              await ref
                                  .read(providerActionsProvider)
                                  .deleteProvider(config.id);
                            }
                          },
                          itemBuilder: (context) => [
                            const PopupMenuItem(
                                value: 'edit', child: Text('Edit')),
                            if (!config.isDefault)
                              const PopupMenuItem(
                                  value: 'make_default',
                                  child: Text('Make Default')),
                            const PopupMenuItem(
                              value: 'delete',
                              child: Text('Delete',
                                  style: TextStyle(color: Colors.redAccent)),
                            ),
                          ],
                        ),
                        onTap: () => context.push(AppRoutes.settingsProviderEdit,
                            extra: config.id),
                      ),
                    ),
                  ),
                const SizedBox(height: 12),
                GlassButton(
                  label: 'Add Another Provider',
                  icon: AppIcons.plus,
                  expanded: true,
                  onPressed: () => context.push(AppRoutes.settingsProviderEdit),
                ),
              ],
            ),
    );
  }
}

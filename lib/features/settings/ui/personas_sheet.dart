import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pocketstrike/app/theme/glass_tokens.dart';
import 'package:pocketstrike/shared/widgets/app_icons.dart';
import 'package:pocketstrike/shared/widgets/glass_button.dart';
import 'package:pocketstrike/features/conversations/application/conversations_controller.dart';
import 'persona_edit_dialog.dart';

/// Horizontal persona chips in drawer + sheet for managing custom personas.
class PersonaSwitcherRow extends ConsumerWidget {
  const PersonaSwitcherRow({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.glass;
    final personas = ref.watch(personasProvider).valueOrNull ?? const [];
    final selectedId = ref.watch(selectedPersonaIdProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 6),
          child: Row(
            children: [
              Text(
                'PERSONA',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: tokens.textSecondary,
                      letterSpacing: 1.0,
                      fontWeight: FontWeight.w700,
                      fontSize: 10,
                    ),
              ),
              const Spacer(),
              Material(
                color: tokens.accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => PersonasSheet.show(context),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: tokens.accent.withValues(alpha: 0.35),
                        width: 0.8,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(AppIcons.sliders, size: 11, color: tokens.accent),
                        const SizedBox(width: 4),
                        Text(
                          'Manage',
                          style: TextStyle(
                            fontSize: 10.5,
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
        SizedBox(
          height: 36,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: personas.length,
            itemBuilder: (context, i) {
              final p = personas[i];
              final isSelected = p.id == selectedId;
              final iconChar = _parseIcon(p.icon);

              return Padding(
                padding: const EdgeInsets.only(right: 6),
                child: ChoiceChip(
                  label: Text('$iconChar ${p.name}'),
                  selected: isSelected,
                  selectedColor: tokens.accent.withValues(alpha: 0.2),
                  backgroundColor: tokens.glassColor,
                  side: BorderSide(
                    color: isSelected
                        ? tokens.accent.withValues(alpha: 0.45)
                        : tokens.glassBorder,
                    width: 0.8,
                  ),
                  labelStyle: TextStyle(
                    fontSize: 11.5,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    color: isSelected
                        ? tokens.accent
                        : Theme.of(context).colorScheme.onSurface,
                  ),
                  onSelected: (val) {
                    if (val) {
                      HapticFeedback.selectionClick();
                      ref.read(selectedPersonaIdProvider.notifier).state = p.id;
                    }
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  String _parseIcon(String icon) {
    if (icon == 'sparkle') return '⚡';
    if (icon == 'code') return '💻';
    if (icon == 'magnifyingGlass') return '🔍';
    return icon;
  }
}

class PersonasSheet extends ConsumerWidget {
  const PersonasSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const PersonasSheet(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.glass;
    final theme = Theme.of(context);
    final personas = ref.watch(personasProvider).valueOrNull ?? const [];

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(tokens.radiusLg),
        ),
        border: Border(top: BorderSide(color: tokens.glassBorder, width: 0.8)),
      ),
      padding: EdgeInsets.fromLTRB(
        16,
        16,
        16,
        16 + MediaQuery.of(context).viewPadding.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(AppIcons.brain, color: tokens.accent, size: 20),
              const SizedBox(width: 8),
              Text('System Personas', style: theme.textTheme.titleMedium?.copyWith(fontSize: 16)),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close, size: 20),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: personas.length,
              itemBuilder: (context, index) {
                final p = personas[index];
                final iconChar = switch (p.icon) {
                  'sparkle' => '⚡',
                  'code' => '💻',
                  'magnifyingGlass' => '🔍',
                  _ => p.icon,
                };

                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: tokens.glassColor,
                    borderRadius: BorderRadius.circular(tokens.radiusSm),
                    border: Border.all(color: tokens.glassBorder, width: 0.8),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(tokens.radiusSm),
                    child: ListTile(
                      dense: true,
                      leading: Text(iconChar, style: const TextStyle(fontSize: 22)),
                      title: Text(
                        p.name,
                        style: theme.textTheme.titleMedium?.copyWith(fontSize: 13.5),
                      ),
                      subtitle: Text(
                        p.systemPrompt,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: tokens.textSecondary, fontSize: 11.5),
                      ),
                      trailing: p.isBuiltIn
                          ? Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: tokens.accent.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: tokens.accent.withValues(alpha: 0.3),
                                  width: 0.8,
                                ),
                              ),
                              child: Text(
                                'BUILT-IN',
                                style: TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.bold,
                                  color: tokens.accent,
                                ),
                              ),
                            )
                          : Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(AppIcons.edit, size: 16),
                                  onPressed: () => PersonaEditDialog.show(context, persona: p),
                                ),
                                IconButton(
                                  icon: const Icon(AppIcons.trash2, size: 16, color: Colors.redAccent),
                                  onPressed: () => ref
                                      .read(personaActionsProvider)
                                      .deletePersona(p.id),
                                ),
                              ],
                            ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          GlassButton(
            label: 'Create Custom Persona',
            icon: AppIcons.plus,
            onPressed: () {
              Navigator.pop(context);
              PersonaEditDialog.show(context);
            },
          ),
        ],
      ),
    );
  }
}

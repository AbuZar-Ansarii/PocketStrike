import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/theme/app_theme.dart';
import '../../app/theme/glass_tokens.dart';

/// Result of a destructive/sensitive action confirmation.
enum ConfirmResult { allow, allowAlways, deny }

/// One-tap confirmation sheet used before destructive agent actions
/// (delete/overwrite file, MCP tool calls, external sends).
class ConfirmActionSheet extends StatelessWidget {
  const ConfirmActionSheet({
    super.key,
    required this.title,
    required this.description,
    this.arguments,
    this.showAllowAlways = false,
  });

  final String title;
  final String description;

  /// Pretty-printed tool arguments shown in a terminal-styled block.
  final Map<String, dynamic>? arguments;
  final bool showAllowAlways;

  /// Pops a modal bottom sheet and resolves with the user's decision.
  static Future<ConfirmResult> show(
    BuildContext context, {
    required String title,
    required String description,
    Map<String, dynamic>? arguments,
    bool showAllowAlways = false,
  }) async {
    HapticFeedback.mediumImpact();
    final result = await showModalBottomSheet<ConfirmResult>(
      context: context,
      isScrollControlled: true,
      builder: (_) => ConfirmActionSheet(
        title: title,
        description: description,
        arguments: arguments,
        showAllowAlways: showAllowAlways,
      ),
    );
    return result ?? ConfirmResult.deny;
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.glass;
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
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
              Icon(Icons.shield_outlined, color: tokens.accent, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: tokens.textSecondary),
          ),
          if (arguments != null && arguments!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: tokens.terminalSurface,
                borderRadius: BorderRadius.circular(tokens.radiusSm),
                border: Border.all(color: tokens.glassBorder),
              ),
              child: Text(
                const JsonEncoder.withIndent('  ').convert(arguments),
                style: AppTheme.mono(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ),
          ],

          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () =>
                      Navigator.of(context).pop(ConfirmResult.deny),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: tokens.glassBorder),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(tokens.radiusSm),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text('Deny'),
                ),
              ),
              const SizedBox(width: 10),
              if (showAllowAlways) ...[
                Expanded(
                  child: OutlinedButton(
                    onPressed: () =>
                        Navigator.of(context).pop(ConfirmResult.allowAlways),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: tokens.accent,
                      side: BorderSide(color: tokens.accent),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(tokens.radiusSm),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('Always'),
                  ),
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: FilledButton(
                  onPressed: () {
                    HapticFeedback.selectionClick();
                    Navigator.of(context).pop(ConfirmResult.allow);
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: tokens.accent,
                    foregroundColor: tokens.onAccent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(tokens.radiusSm),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text('Allow'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

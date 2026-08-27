import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/theme/glass_tokens.dart';

/// Accent-filled button with haptic feedback and a pressed-state color swap.
class GlassButton extends StatefulWidget {
  const GlassButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.expanded = false,
    this.danger = false,
  });

  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool expanded;
  final bool danger;

  @override
  State<GlassButton> createState() => _GlassButtonState();
}

class _GlassButtonState extends State<GlassButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final tokens = context.glass;
    final enabled = widget.onPressed != null;
    final base = widget.danger
        ? Theme.of(context).colorScheme.error
        : tokens.accent;
    final pressed = widget.danger
        ? Theme.of(context).colorScheme.error.withValues(alpha: 0.8)
        : tokens.accentPressed;

    final child = AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      decoration: BoxDecoration(
        color: enabled
            ? (_pressed ? pressed : base)
            : base.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(tokens.radiusSm),
      ),
      child: Row(
        mainAxisSize: widget.expanded ? MainAxisSize.max : MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (widget.icon != null) ...[
            Icon(widget.icon, size: 18, color: tokens.onAccent),
            const SizedBox(width: 8),
          ],
          Text(
            widget.label,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: tokens.onAccent,
                  fontSize: 14,
                ),
          ),
        ],
      ),
    );

    return GestureDetector(
      onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
      onTapCancel: enabled ? () => setState(() => _pressed = false) : null,
      onTapUp: enabled ? (_) => setState(() => _pressed = false) : null,
      onTap: enabled
          ? () {
              HapticFeedback.selectionClick();
              widget.onPressed!();
            }
          : null,
      child: widget.expanded
          ? SizedBox(width: double.infinity, child: child)
          : child,
    );
  }
}

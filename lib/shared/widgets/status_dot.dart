import 'package:flutter/material.dart';

import '../../app/theme/app_palette.dart';
import '../../app/theme/glass_tokens.dart';

enum StatusDotState { connected, error, reconnecting, idle }

/// Small colored status indicator (MCP connections, providers).
class StatusDot extends StatelessWidget {
  const StatusDot({super.key, required this.state, this.size = 8});

  final StatusDotState state;
  final double size;

  @override
  Widget build(BuildContext context) {
    final color = switch (state) {
      StatusDotState.connected => context.glass.accent,
      StatusDotState.error => AppPalette.error,
      StatusDotState.reconnecting => AppPalette.warning,
      StatusDotState.idle => context.glass.textSecondary.withValues(alpha: 0.5),
    };
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: state == StatusDotState.connected
            ? [BoxShadow(color: color.withValues(alpha: 0.6), blurRadius: 6)]
            : null,
      ),
    );
  }
}

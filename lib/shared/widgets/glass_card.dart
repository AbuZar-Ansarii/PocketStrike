import 'dart:ui';

import 'package:flutter/material.dart';

import '../../app/theme/glass_tokens.dart';

/// Frosted-glass panel: BackdropFilter blur + translucent fill + subtle border.
class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.borderRadius,
    this.blur = true,
    this.color,
    this.border,
    this.shadow = false,
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final BorderRadius? borderRadius;
  final bool blur;
  final Color? color;
  final Border? border;
  final bool shadow;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.glass;
    final radius = borderRadius ?? BorderRadius.circular(tokens.radiusMd);

    Widget content = Container(
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color ?? tokens.glassColor,
        borderRadius: radius,
        border: border ?? Border.all(color: tokens.glassBorder),
        boxShadow: shadow ? tokens.softShadow : null,
      ),
      child: child,
    );

    if (blur) {
      content = ClipRRect(
        borderRadius: radius,
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: tokens.blurSigma,
            sigmaY: tokens.blurSigma,
          ),
          child: content,
        ),
      );
    }

    if (onTap != null) {
      content = Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          child: content,
        ),
      );
    }

    return Container(margin: margin, child: content);
  }
}

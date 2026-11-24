import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_theme.dart';

/// Canvas root: deep obsidian with a soft radial glow from the centre.
class ArcadeBackground extends StatelessWidget {
  const ArcadeBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(
      color: AppColors.canvas,
      gradient: RadialGradient(
        center: Alignment(0, -0.1),
        radius: 1.1,
        colors: [Color(0xFF161B33), AppColors.canvas],
      ),
    ),
    child: child,
  );
}

/// Floating glass deck: translucent obsidian, blur, top-lit hairline border.
class GlassPanel extends StatelessWidget {
  const GlassPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.radius = 16,
    this.glow,
    this.tint,
    this.blur = true,
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final Color? glow;
  final Color? tint;
  final bool blur;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(radius);
    Widget body = Container(
      padding: padding,
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        color: (tint ?? AppColors.deck).withValues(alpha: 0.82),
        border: Border.all(color: Colors.white.withValues(alpha: 0.09)),
        boxShadow: glow == null
            ? null
            : [BoxShadow(color: glow!.withValues(alpha: 0.28), blurRadius: 24)],
      ),
      child: child,
    );
    if (onTap != null) {
      body = Material(
        type: MaterialType.transparency,
        child: InkWell(borderRadius: borderRadius, onTap: onTap, child: body),
      );
    }
    final clipped = ClipRRect(
      borderRadius: borderRadius,
      child: blur
          ? BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 16, sigmaY: 16),
              child: body,
            )
          : body,
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        boxShadow: glow == null
            ? null
            : [BoxShadow(color: glow!.withValues(alpha: 0.18), blurRadius: 22)],
      ),
      child: clipped,
    );
  }
}

/// Primary action: cyan fill, 3px bottom bevel, presses down 2px.
class JuicyButton extends StatefulWidget {
  const JuicyButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.color = AppColors.cyan,
    this.bevel = AppColors.cyanBevel,
    this.height = 56,
  });

  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final Color color;
  final Color bevel;
  final double height;

  @override
  State<JuicyButton> createState() => _JuicyButtonState();
}

class _JuicyButtonState extends State<JuicyButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    final radius = BorderRadius.circular(14);
    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: enabled ? (_) => setState(() => _down = true) : null,
        onTapCancel: enabled ? () => setState(() => _down = false) : null,
        onTapUp: enabled ? (_) => setState(() => _down = false) : null,
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 70),
          height: widget.height,
          margin: EdgeInsets.only(top: _down ? 2 : 0, bottom: _down ? 0 : 2),
          decoration: BoxDecoration(
            borderRadius: radius,
            color: enabled ? widget.color : AppColors.track,
            boxShadow: [
              BoxShadow(
                color: enabled ? widget.bevel : AppColors.well,
                offset: Offset(0, _down ? 1 : 3),
              ),
              if (enabled && !_down)
                BoxShadow(
                  color: widget.color.withValues(alpha: 0.4),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
            ],
          ),
          child: Stack(
            children: [
              Positioned(
                left: 8,
                right: 8,
                top: 1,
                height: 1,
                child: ColoredBox(color: Colors.white.withValues(alpha: 0.55)),
              ),
              Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (widget.icon != null) ...[
                      Icon(widget.icon, color: AppColors.canvas, size: 22),
                      const SizedBox(width: 8),
                    ],
                    Flexible(
                      child: Text(
                        widget.label,
                        overflow: TextOverflow.ellipsis,
                        style: AppTheme.sora(
                          16,
                          weight: FontWeight.w800,
                          color: AppColors.canvas,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Secondary action: dark glass with a violet hairline stroke.
class GlassButton extends StatelessWidget {
  const GlassButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.stroke = AppColors.violet,
    this.height = 50,
  });

  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final Color stroke;
  final double height;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(14);
    return Material(
      color: AppColors.deck.withValues(alpha: 0.9),
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: BorderSide(color: stroke.withValues(alpha: 0.8)),
      ),
      child: InkWell(
        borderRadius: radius,
        onTap: onPressed,
        child: SizedBox(
          height: height,
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(icon, color: AppColors.onSurface, size: 20),
                  const SizedBox(width: 8),
                ],
                Flexible(
                  child: Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                    style: AppTheme.sora(14, weight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Small rounded counter / badge (streak, timer, level).
class StatPill extends StatelessWidget {
  const StatPill({
    super.key,
    required this.text,
    this.icon,
    this.color = AppColors.amber,
    this.glow = false,
  });

  final String text;
  final IconData? icon;
  final Color color;
  final bool glow;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(999),
      color: color.withValues(alpha: 0.12),
      border: Border.all(color: color.withValues(alpha: 0.5)),
      boxShadow: glow
          ? [BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 8)]
          : null,
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 6),
        ],
        Text(text, style: AppTheme.grotesk(13, color: color)),
      ],
    ),
  );
}

/// Section caption: small icon + Space Grotesk label.
class SectionLabel extends StatelessWidget {
  const SectionLabel(
    this.text, {
    super.key,
    this.icon,
    this.color = AppColors.cyan,
  });

  final String text;
  final IconData? icon;
  final Color color;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      if (icon != null) ...[
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 8),
      ],
      Flexible(
        child: Text(
          text.toUpperCase(),
          style: AppTheme.grotesk(12, color: AppColors.onSurfaceVariant),
        ),
      ),
    ],
  );
}

/// Top bar: optional back button, logo wordmark + subtitle, trailing widget.
class ArcadeHeader extends StatelessWidget {
  const ArcadeHeader({
    super.key,
    required this.subtitle,
    this.showBack = false,
    this.trailing,
  });

  final String subtitle;
  final bool showBack;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
    child: Row(
      children: [
        if (showBack) ...[
          _SquareIconButton(
            icon: Icons.arrow_back_rounded,
            tooltip: 'Back',
            onTap: () => Navigator.maybePop(context),
          ),
          const SizedBox(width: 12),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'GridSpark',
                style: AppTheme.sora(
                  20,
                  weight: FontWeight.w800,
                  color: AppColors.cyan,
                ),
              ),
              Text(subtitle.toUpperCase(), style: AppTheme.grotesk(11)),
            ],
          ),
        ),
        if (trailing != null) trailing!,
      ],
    ),
  );
}

class _SquareIconButton extends StatelessWidget {
  const _SquareIconButton({
    required this.icon,
    required this.onTap,
    required this.tooltip,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: Material(
      color: AppColors.deck,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.white.withValues(alpha: 0.09)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(icon, color: AppColors.onSurface),
        ),
      ),
    ),
  );
}

/// Square glass icon button used for pause / header actions.
class ArcadeIconButton extends StatelessWidget {
  const ArcadeIconButton({
    super.key,
    required this.icon,
    required this.onTap,
    required this.tooltip,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final String tooltip;

  @override
  Widget build(BuildContext context) => Opacity(
    opacity: onTap == null ? 0.4 : 1,
    child: _SquareIconButton(
      icon: icon,
      onTap: onTap ?? () {},
      tooltip: tooltip,
    ),
  );
}

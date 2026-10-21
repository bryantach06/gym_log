import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Volt tile with a bolt, optionally followed by the GYMLOG wordmark.
class BrandMark extends StatelessWidget {
  final double size;
  final bool showWordmark;

  const BrandMark({super.key, this.size = 44, this.showWordmark = true});

  @override
  Widget build(BuildContext context) {
    final gym = GymColors.of(context);
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: gym.accent,
            borderRadius: BorderRadius.circular(size * 0.28),
          ),
          child: Icon(Icons.bolt_rounded, color: gym.onAccent, size: size * 0.66),
        ),
        if (showWordmark) ...[
          SizedBox(width: size * 0.28),
          Text(
            'GYMLOG',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontSize: size * 0.62,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.5,
            ),
          ),
        ],
      ],
    );
  }
}

/// Faint concentric rings, like weight plates, for decorative backgrounds.
class PlateRings extends StatelessWidget {
  final double size;
  const PlateRings({super.key, this.size = 360});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        size: Size.square(size),
        painter: _RingsPainter(Theme.of(context).colorScheme.outlineVariant),
      ),
    );
  }
}

class _RingsPainter extends CustomPainter {
  final Color color;
  _RingsPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..color = color;
    final r = size.width / 2;
    for (final (f, w) in [(1.0, 1.5), (0.82, 10.0), (0.62, 1.5), (0.5, 1.5), (0.18, 12.0)]) {
      paint.strokeWidth = w;
      canvas.drawCircle(center, r * f - w / 2, paint);
    }
  }

  @override
  bool shouldRepaint(_RingsPainter old) => old.color != color;
}

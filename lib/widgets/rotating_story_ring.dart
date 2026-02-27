import 'dart:math' as math;
import 'package:flutter/material.dart';

class RotatingStoryRing extends StatefulWidget {
  final bool hasStory;
  final Widget child;
  final double size;
  final Color color;
  final double strokeWidth;

  const RotatingStoryRing({
    super.key,
    required this.hasStory,
    required this.child,
    this.size = 62,
    this.color = const Color(0xFFDD2A7B),
    this.strokeWidth = 2.5,
  });

  @override
  State<RotatingStoryRing> createState() => _RotatingStoryRingState();
}

class _RotatingStoryRingState extends State<RotatingStoryRing>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );
    if (widget.hasStory) _controller.repeat();
  }

  @override
  void didUpdateWidget(RotatingStoryRing oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.hasStory && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!widget.hasStory && _controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (!widget.hasStory) {
      // Static grey border when no story
      return Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: isDark ? Colors.white24 : Colors.black12,
            width: widget.strokeWidth,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(2),
          child: widget.child,
        ),
      );
    }

    // Animated rotating gradient ring
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          painter: _StoryRingPainter(
            color: widget.color,
            rotation: _controller.value * 2 * math.pi,
            strokeWidth: widget.strokeWidth,
          ),
          child: SizedBox(
            width: widget.size,
            height: widget.size,
            child: Padding(
              padding: EdgeInsets.all(widget.strokeWidth + 1.5),
              child: widget.child,
            ),
          ),
        );
      },
    );
  }
}

class _StoryRingPainter extends CustomPainter {
  final Color color;
  final double rotation;
  final double strokeWidth;

  _StoryRingPainter({
    required this.color,
    required this.rotation,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width / 2) - strokeWidth / 2;

    // Derive secondary color for gradient
    final hsl = HSLColor.fromColor(color);
    final secondaryColor = hsl
        .withHue((hsl.hue + 120) % 360)
        .toColor();

    final paint = Paint()
      ..shader = SweepGradient(
        startAngle: rotation,
        endAngle: rotation + 2 * math.pi,
        colors: [
          color,
          secondaryColor,
          color.withAlpha(180),
          color,
        ],
        stops: const [0.0, 0.33, 0.66, 1.0],
        transform: GradientRotation(rotation),
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    // Draw segmented ring (Instagram-style dashes)
    const segments = 4;
    const gapAngle = 0.08; // Radians gap between segments
    final segmentAngle = (2 * math.pi - segments * gapAngle) / segments;

    for (int i = 0; i < segments; i++) {
      final startAngle = rotation + i * (segmentAngle + gapAngle) - math.pi / 2;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        segmentAngle,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_StoryRingPainter oldDelegate) =>
      oldDelegate.rotation != rotation ||
      oldDelegate.color != color;
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ═══════════════════════════════════════════════════════
// CUSTOM PAGE ROUTE TRANSITIONS
// ═══════════════════════════════════════════════════════

/// Slide-up transition (like Instagram story/modal)
class SlideUpRoute<T> extends PageRouteBuilder<T> {
  final Widget page;
  SlideUpRoute({required this.page})
      : super(
          pageBuilder: (_, __, ___) => page,
          transitionDuration: const Duration(milliseconds: 350),
          reverseTransitionDuration: const Duration(milliseconds: 300),
          transitionsBuilder: (ctx, anim, secondaryAnim, child) {
            final curved = CurvedAnimation(
              parent: anim,
              curve: Curves.easeOutCubic,
              reverseCurve: Curves.easeInCubic,
            );
            return SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 1),
                end: Offset.zero,
              ).animate(curved),
              child: child,
            );
          },
        );
}

/// Slide-right transition (standard navigation push)
class SlideRightRoute<T> extends PageRouteBuilder<T> {
  final Widget page;
  SlideRightRoute({required this.page})
      : super(
          pageBuilder: (_, __, ___) => page,
          transitionDuration: const Duration(milliseconds: 300),
          reverseTransitionDuration: const Duration(milliseconds: 250),
          transitionsBuilder: (ctx, anim, secondaryAnim, child) {
            final curved = CurvedAnimation(
              parent: anim,
              curve: Curves.easeOutCubic,
              reverseCurve: Curves.easeInCubic,
            );
            return SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(1, 0),
                end: Offset.zero,
              ).animate(curved),
              child: FadeTransition(
                opacity: Tween<double>(begin: 0.5, end: 1.0).animate(curved),
                child: child,
              ),
            );
          },
        );
}

/// Fade-scale transition (for modals, popups)
class FadeScaleRoute<T> extends PageRouteBuilder<T> {
  final Widget page;
  FadeScaleRoute({required this.page})
      : super(
          pageBuilder: (_, __, ___) => page,
          transitionDuration: const Duration(milliseconds: 300),
          reverseTransitionDuration: const Duration(milliseconds: 200),
          transitionsBuilder: (ctx, anim, secondaryAnim, child) {
            final curved = CurvedAnimation(
              parent: anim,
              curve: Curves.easeOutBack,
              reverseCurve: Curves.easeIn,
            );
            return FadeTransition(
              opacity: curved,
              child: ScaleTransition(
                scale: Tween<double>(begin: 0.85, end: 1.0).animate(curved),
                child: child,
              ),
            );
          },
        );
}

/// Shared-axis horizontal transition
class SharedAxisRoute<T> extends PageRouteBuilder<T> {
  final Widget page;
  SharedAxisRoute({required this.page})
      : super(
          pageBuilder: (_, __, ___) => page,
          transitionDuration: const Duration(milliseconds: 400),
          reverseTransitionDuration: const Duration(milliseconds: 350),
          transitionsBuilder: (ctx, anim, secondaryAnim, child) {
            final curved = CurvedAnimation(
              parent: anim,
              curve: Curves.fastOutSlowIn,
            );
            return FadeTransition(
              opacity: curved,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0.05, 0),
                  end: Offset.zero,
                ).animate(curved),
                child: child,
              ),
            );
          },
        );
}

// ═══════════════════════════════════════════════════════
// SHIMMER LOADING PLACEHOLDER
// ═══════════════════════════════════════════════════════

class ShimmerLoading extends StatefulWidget {
  final double width;
  final double height;
  final double borderRadius;
  final bool isCircle;

  const ShimmerLoading({
    super.key,
    this.width = double.infinity,
    this.height = 16,
    this.borderRadius = 8,
    this.isCircle = false,
  });

  @override
  State<ShimmerLoading> createState() => _ShimmerLoadingState();
}

class _ShimmerLoadingState extends State<ShimmerLoading>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
    _animation = Tween<double>(begin: -2, end: 2).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final base = isDark ? const Color(0xFF1A1A2E) : const Color(0xFFE8E8E8);
    final highlight = isDark ? const Color(0xFF2A2A4E) : const Color(0xFFF5F5F5);

    return AnimatedBuilder(
      animation: _animation,
      builder: (_, __) => Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          shape: widget.isCircle ? BoxShape.circle : BoxShape.rectangle,
          borderRadius: widget.isCircle ? null : BorderRadius.circular(widget.borderRadius),
          gradient: LinearGradient(
            begin: Alignment(_animation.value - 1, 0),
            end: Alignment(_animation.value + 1, 0),
            colors: [base, highlight, base],
            stops: const [0.0, 0.5, 1.0],
          ),
        ),
      ),
    );
  }
}

/// Pre-built shimmer layouts
class ShimmerPostCard extends StatelessWidget {
  const ShimmerPostCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                const ShimmerLoading(width: 38, height: 38, isCircle: true),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    ShimmerLoading(width: 100, height: 12),
                    SizedBox(height: 4),
                    ShimmerLoading(width: 60, height: 10),
                  ],
                ),
              ],
            ),
          ),
          // Image placeholder
          const ShimmerLoading(height: 300, borderRadius: 0),
          // Action buttons
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: const [
                ShimmerLoading(width: 26, height: 26, isCircle: true),
                SizedBox(width: 16),
                ShimmerLoading(width: 24, height: 24, isCircle: true),
                SizedBox(width: 16),
                ShimmerLoading(width: 24, height: 24, isCircle: true),
                Spacer(),
                ShimmerLoading(width: 24, height: 24, isCircle: true),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 14),
            child: ShimmerLoading(width: 80, height: 12),
          ),
          const SizedBox(height: 6),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 14),
            child: ShimmerLoading(width: 200, height: 12),
          ),
        ],
      ),
    );
  }
}

class ShimmerStoryCircle extends StatelessWidget {
  const ShimmerStoryCircle({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Column(
        children: const [
          ShimmerLoading(width: 62, height: 62, isCircle: true),
          SizedBox(height: 4),
          ShimmerLoading(width: 50, height: 10),
        ],
      ),
    );
  }
}

class ShimmerProfileHeader extends StatelessWidget {
  const ShimmerProfileHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 16),
        const ShimmerLoading(width: 100, height: 100, isCircle: true),
        const SizedBox(height: 12),
        const ShimmerLoading(width: 120, height: 18),
        const SizedBox(height: 6),
        const ShimmerLoading(width: 180, height: 12),
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: const [
            ShimmerLoading(width: 60, height: 40),
            ShimmerLoading(width: 60, height: 40),
            ShimmerLoading(width: 80, height: 40, borderRadius: 20),
          ],
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════
// STAGGERED FADE-IN ANIMATION
// ═══════════════════════════════════════════════════════

class FadeInSlide extends StatefulWidget {
  final Widget child;
  final int delay; // milliseconds
  final double offsetY;
  final double offsetX;
  final Duration duration;
  final Curve curve;

  const FadeInSlide({
    super.key,
    required this.child,
    this.delay = 0,
    this.offsetY = 20,
    this.offsetX = 0,
    this.duration = const Duration(milliseconds: 400),
    this.curve = Curves.easeOutCubic,
  });

  @override
  State<FadeInSlide> createState() => _FadeInSlideState();
}

class _FadeInSlideState extends State<FadeInSlide>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacity;
  late Animation<Offset> _offset;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    final curved = CurvedAnimation(parent: _controller, curve: widget.curve);
    _opacity = Tween<double>(begin: 0, end: 1).animate(curved);
    _offset = Tween<Offset>(
      begin: Offset(widget.offsetX, widget.offsetY),
      end: Offset.zero,
    ).animate(curved);

    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, child) => Opacity(
        opacity: _opacity.value,
        child: Transform.translate(
          offset: _offset.value,
          child: child,
        ),
      ),
      child: widget.child,
    );
  }
}

// ═══════════════════════════════════════════════════════
// ANIMATED SCALE TAP WRAPPER
// ═══════════════════════════════════════════════════════

class ScaleTap extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double scaleDown;

  const ScaleTap({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.scaleDown = 0.95,
  });

  @override
  State<ScaleTap> createState() => _ScaleTapState();
}

class _ScaleTapState extends State<ScaleTap>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
      reverseDuration: const Duration(milliseconds: 200),
    );
    _scale = Tween<double>(begin: 1.0, end: widget.scaleDown).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) {
        _controller.reverse();
        HapticFeedback.lightImpact();
        widget.onTap?.call();
      },
      onTapCancel: () => _controller.reverse(),
      onLongPress: widget.onLongPress != null
          ? () {
              HapticFeedback.mediumImpact();
              widget.onLongPress!();
            }
          : null,
      child: ScaleTransition(
        scale: _scale,
        child: widget.child,
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════
// ANIMATED COUNTER TEXT
// ═══════════════════════════════════════════════════════

class AnimatedCount extends StatelessWidget {
  final int count;
  final TextStyle? style;

  const AnimatedCount({super.key, required this.count, this.style});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<int>(
      tween: IntTween(begin: 0, end: count),
      duration: const Duration(milliseconds: 800),
      curve: Curves.easeOutCubic,
      builder: (_, value, __) => Text(
        _format(value),
        style: style,
      ),
    );
  }

  String _format(int count) {
    if (count >= 1000000) return '${(count / 1000000).toStringAsFixed(1)}M';
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}K';
    return count.toString();
  }
}

// ═══════════════════════════════════════════════════════
// HERO-LIKE CARD WRAPPER
// ═══════════════════════════════════════════════════════

class AnimatedListItem extends StatelessWidget {
  final int index;
  final Widget child;

  const AnimatedListItem({
    super.key,
    required this.index,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return FadeInSlide(
      delay: (index * 60).clamp(0, 600),
      offsetY: 30,
      duration: const Duration(milliseconds: 500),
      child: child,
    );
  }
}

// ═══════════════════════════════════════════════════════
// PULSING DOT INDICATOR (for loading/live)
// ═══════════════════════════════════════════════════════

class PulsingDot extends StatefulWidget {
  final Color color;
  final double size;

  const PulsingDot({super.key, required this.color, this.size = 8});

  @override
  State<PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<PulsingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, __) => Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          color: widget.color.withAlpha((150 + 105 * _controller.value).toInt()),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: widget.color.withAlpha((80 * _controller.value).toInt()),
              blurRadius: widget.size * _controller.value,
              spreadRadius: widget.size * 0.3 * _controller.value,
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════
// GLASSMORPHISM CONTAINER
// ═══════════════════════════════════════════════════════

class GlassContainer extends StatelessWidget {
  final Widget child;
  final double borderRadius;
  final EdgeInsets padding;
  final EdgeInsets margin;

  const GlassContainer({
    super.key,
    required this.child,
    this.borderRadius = 16,
    this.padding = const EdgeInsets.all(16),
    this.margin = EdgeInsets.zero,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        color: isDark
            ? Colors.white.withAlpha(10)
            : Colors.white.withAlpha(180),
        border: Border.all(
          color: isDark
              ? Colors.white.withAlpha(15)
              : Colors.white.withAlpha(200),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(isDark ? 30 : 8),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }
}

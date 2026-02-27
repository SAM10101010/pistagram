import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AchievementPopup extends StatefulWidget {
  final String title;
  final String description;
  final String icon;
  final VoidCallback? onDismiss;

  const AchievementPopup({
    super.key,
    required this.title,
    required this.description,
    this.icon = 'star',
    this.onDismiss,
  });

  @override
  State<AchievementPopup> createState() => _AchievementPopupState();
}

class _AchievementPopupState extends State<AchievementPopup>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scale;
  late Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _scale = Tween<double>(
      begin: 0.3,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.elasticOut));
    _opacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.3, curve: Curves.easeIn),
      ),
    );
    _controller.forward();

    // Auto-dismiss after 3.5 seconds
    Future.delayed(const Duration(milliseconds: 3500), () {
      if (mounted) {
        _controller.reverse().then((_) {
          widget.onDismiss?.call();
        });
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Opacity(
          opacity: _opacity.value,
          child: Transform.scale(scale: _scale.value, child: child),
        );
      },
      child: Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 40),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1A1A2E) : Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: accent.withAlpha(60),
                blurRadius: 30,
                spreadRadius: 2,
              ),
            ],
            border: Border.all(color: accent.withAlpha(80)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [accent, accent.withAlpha(150)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Icon(
                  _getIcon(widget.icon),
                  color: Colors.white,
                  size: 32,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Achievement Unlocked!',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: accent,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                widget.title,
                style: GoogleFonts.outfit(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : Colors.black87,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                widget.description,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: isDark ? Colors.white54 : Colors.black54,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getIcon(String iconName) {
    switch (iconName) {
      case 'play_arrow':
        return Icons.play_arrow_rounded;
      case 'visibility':
        return Icons.visibility_rounded;
      case 'local_fire_department':
        return Icons.local_fire_department_rounded;
      case 'whatshot':
        return Icons.whatshot_rounded;
      case 'bolt':
        return Icons.bolt_rounded;
      case 'favorite':
        return Icons.favorite_rounded;
      case 'chat_bubble':
        return Icons.chat_bubble_rounded;
      case 'shopping_bag':
        return Icons.shopping_bag_rounded;
      case 'trending_up':
        return Icons.trending_up_rounded;
      case 'star':
        return Icons.star_rounded;
      case 'diamond':
        return Icons.diamond_rounded;
      default:
        return Icons.emoji_events_rounded;
    }
  }
}

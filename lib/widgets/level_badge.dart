import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/level_service.dart';

class LevelBadge extends StatelessWidget {
  final String level;
  final bool compact;

  const LevelBadge({super.key, required this.level, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final info = LevelService.getLevelInfo(level);
    final color = Color(info['color'] as int);
    final name = info['name'] as String;

    if (compact) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: color.withAlpha(30),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withAlpha(80), width: 0.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(_getIcon(info['icon'] as String), size: 10, color: color),
            const SizedBox(width: 3),
            Text(
              name,
              style: GoogleFonts.inter(
                fontSize: 9,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withAlpha(40), color.withAlpha(15)],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withAlpha(80)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withAlpha(50),
            ),
            child: Icon(
              _getIcon(info['icon'] as String),
              size: 12,
              color: color,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            name,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  IconData _getIcon(String iconName) {
    switch (iconName) {
      case 'diamond':
        return Icons.diamond_rounded;
      case 'star':
        return Icons.star_rounded;
      case 'trending_up':
        return Icons.trending_up_rounded;
      default:
        return Icons.person_rounded;
    }
  }
}

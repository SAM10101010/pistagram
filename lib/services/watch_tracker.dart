import 'package:video_player/video_player.dart';

class WatchTracker {
  final VideoPlayerController controller;
  final String reelId;
  final void Function(String reelId) onCompleted;
  bool _hasTriggered = false;

  /// Minimum reel duration to earn points (60 seconds)
  static const Duration minDuration = Duration(seconds: 60);

  WatchTracker({
    required this.controller,
    required this.reelId,
    required this.onCompleted,
  }) {
    controller.addListener(_checkProgress);
  }

  void _checkProgress() {
    if (_hasTriggered) return;

    final duration = controller.value.duration;
    final position = controller.value.position;

    // Skip reels shorter than 60 seconds
    if (duration < minDuration) return;

    // Check for 95% completion
    if (duration.inMilliseconds > 0) {
      final progress = position.inMilliseconds / duration.inMilliseconds;
      if (progress >= 0.95) {
        _hasTriggered = true;
        onCompleted(reelId);
      }
    }
  }

  void dispose() {
    controller.removeListener(_checkProgress);
  }
}

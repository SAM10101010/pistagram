import 'package:video_player/video_player.dart';

class WatchTracker {
  final VideoPlayerController controller;
  final String reelId;
  final Function(String reelId) onCompleted;
  bool _hasTriggered = false;

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

    // Award points when the reel reaches 95% (effectively finished)
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

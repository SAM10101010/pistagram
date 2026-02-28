import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AudioPlaybackService {
  AudioPlaybackService._();
  static final AudioPlaybackService _instance = AudioPlaybackService._();
  static AudioPlaybackService get instance => _instance;

  final AudioPlayer _player = AudioPlayer();
  bool _isMuted = false;
  String? _currentUrl;

  bool get isMuted => _isMuted;
  bool get isPlaying => _player.playing;
  String? get currentUrl => _currentUrl;
  Stream<bool> get playingStream => _player.playingStream;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _isMuted = prefs.getBool('audio_muted') ?? false;
    if (_isMuted) _player.setVolume(0);
  }

  Future<void> play(String url) async {
    if (url.isEmpty) return;
    if (_currentUrl == url && _player.playing) return;
    try {
      _currentUrl = url;
      await _player.setUrl(url);
      _player.setVolume(_isMuted ? 0 : 1.0);
      _player.setLoopMode(LoopMode.one);
      await _player.play();
    } catch (_) {}
  }

  Future<void> pause() async {
    try {
      await _player.pause();
    } catch (_) {}
  }

  Future<void> stop() async {
    try {
      await _player.stop();
      _currentUrl = null;
    } catch (_) {}
  }

  Future<void> toggleMute() async {
    _isMuted = !_isMuted;
    _player.setVolume(_isMuted ? 0 : 1.0);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('audio_muted', _isMuted);
  }

  Future<void> setMuted(bool muted) async {
    _isMuted = muted;
    _player.setVolume(_isMuted ? 0 : 1.0);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('audio_muted', _isMuted);
  }

  void dispose() {
    _player.dispose();
  }
}

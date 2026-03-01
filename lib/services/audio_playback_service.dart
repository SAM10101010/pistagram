import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AudioPlaybackService {
  AudioPlaybackService._();
  static final AudioPlaybackService _instance = AudioPlaybackService._();
  static AudioPlaybackService get instance => _instance;

  final AudioPlayer _player = AudioPlayer();
  bool _isMuted = false;
  String? _currentUrl;
  String? _currentFilePath;

  bool get isMuted => _isMuted;
  bool get isPlaying => _player.playing;
  String? get currentUrl => _currentUrl;
  String? get currentFilePath => _currentFilePath;
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
      _currentFilePath = null;
      await _player.setUrl(url);
      _player.setVolume(_isMuted ? 0 : 1.0);
      _player.setLoopMode(LoopMode.one);
      await _player.play();
    } catch (_) {}
  }

  /// Play a local audio file (e.g. for music preview during upload)
  Future<void> playFile(String filePath, {double startSeconds = 0}) async {
    if (filePath.isEmpty) return;
    try {
      _currentFilePath = filePath;
      _currentUrl = null;
      await _player.setFilePath(filePath);
      _player.setVolume(_isMuted ? 0 : 1.0);
      _player.setLoopMode(LoopMode.one);
      if (startSeconds > 0) {
        await _player.seek(Duration(seconds: startSeconds.toInt()));
      }
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
      _currentFilePath = null;
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


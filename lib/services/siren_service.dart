import 'package:flutter/services.dart';

/// SirenService — uses Android's native MediaPlayer via MethodChannel.
/// NO Flutter audio packages. NO ExoPlayer. NO just_audio. NO audioplayers.
/// Calls directly into MainActivity.kt which uses android.media.MediaPlayer.

class SirenService {
  static const _channel = MethodChannel('com.example.mobile_app/siren');
  bool _isPlaying = false;

  Future<void> startSiren() async {
    if (_isPlaying) return;
    try {
      final result = await _channel.invokeMethod<String>('startSiren');
      _isPlaying = true;
      print("[SirenService] ✅ Siren started: $result");
    } on PlatformException catch (e) {
      print("[SirenService] ❌ Platform error: ${e.code} — ${e.message}");
    } catch (e) {
      print("[SirenService] ❌ Error: $e");
    }
  }

  Future<void> stopSiren() async {
    if (!_isPlaying) return;
    try {
      await _channel.invokeMethod<String>('stopSiren');
      _isPlaying = false;
      print("[SirenService] 🔇 Siren stopped");
    } catch (e) {
      print("[SirenService] ❌ Stop error: $e");
    }
  }

  bool get isPlaying => _isPlaying;

  void dispose() {
    stopSiren();
  }
}

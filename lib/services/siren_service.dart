import 'dart:io';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// SirenService — Cross-platform audio siren (Android + iOS)
///
/// Uses audioplayers package for cross-platform support.
/// Falls back to native MethodChannel on Android if needed.

class SirenService {
  // Cross-platform audio player
  final AudioPlayer _player = AudioPlayer();
  bool _isPlaying = false;

  // Android native fallback
  static const _nativeChannel = MethodChannel('com.example.mobile_app/siren');

  Future<void> startSiren() async {
    if (_isPlaying) return;

    try {
      // Cross-platform: use audioplayers
      await _player.setReleaseMode(ReleaseMode.loop);
      await _player.setVolume(1.0);
      await _player.play(AssetSource('sounds/siren.mp3'));
      _isPlaying = true;
      debugPrint('[SirenService] ✅ Siren started (cross-platform)');
    } catch (e) {
      debugPrint(
          '[SirenService] ⚠️ Cross-platform siren failed, trying native: $e');

      // Android fallback: native MediaPlayer
      if (Platform.isAndroid) {
        try {
          await _nativeChannel.invokeMethod<String>('startSiren');
          _isPlaying = true;
          debugPrint('[SirenService] ✅ Siren started (native Android)');
        } on PlatformException catch (ex) {
          debugPrint(
              '[SirenService] ❌ Native siren failed: ${ex.code} — ${ex.message}');
        }
      } else {
        debugPrint(
            '[SirenService] ❌ Siren failed on ${Platform.operatingSystem}: $e');
      }
    }
  }

  Future<void> stopSiren() async {
    if (!_isPlaying) return;

    try {
      await _player.stop();
      _isPlaying = false;
      debugPrint('[SirenService] 🔇 Siren stopped (cross-platform)');
    } catch (e) {
      debugPrint('[SirenService] ⚠️ Cross-platform stop failed: $e');
    }

    // Also stop native if on Android
    if (Platform.isAndroid) {
      try {
        await _nativeChannel.invokeMethod<String>('stopSiren');
      } catch (_) {}
    }

    _isPlaying = false;
  }

  bool get isPlaying => _isPlaying;

  void dispose() {
    stopSiren();
    _player.dispose();
  }
}

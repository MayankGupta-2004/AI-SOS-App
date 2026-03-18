import 'package:flutter/services.dart';

/// RecordingService — Flutter side.
///
/// The 10-minute auto-stop timer lives in the NATIVE Android service
/// (RecordingService.kt → handler.postDelayed).
///
/// This means recording stops correctly even when:
///   - App is swiped from recents
///   - Phone screen is locked
///   - Flutter engine is killed
///
/// This Dart class just starts/stops via MethodChannel.

class RecordingService {
  static const _channel = MethodChannel('com.example.mobile_app/recorder');

  bool _isRecording = false;
  String? _currentFilePath;

  /// Start recording — 10-min timer is managed natively in Android
  Future<void> startRecording({Function(String path)? onSaved}) async {
    if (_isRecording) {
      print("[Recording] Already recording — skipping");
      return;
    }

    try {
      print("[Recording] Starting via native RecordingService...");

      final path = await _channel.invokeMethod<String>('startRecording');

      if (path == null) {
        print("[Recording] No path returned — start failed");
        return;
      }

      _currentFilePath = path;
      _isRecording = true;

      print("[Recording] STARTED: $path");
      print("[Recording] Auto-stop in 10 min (managed by Android service)");

      // Notify caller with path when done
      // Note: since the timer is native, onSaved won't fire when app is killed.
      // The file is still saved correctly on disk regardless.
      onSaved?.call(path);
    } on PlatformException catch (e) {
      print("[Recording] Platform error: ${e.code} — ${e.message}");
    } catch (e) {
      print("[Recording] Error: $e");
    }
  }

  /// Request stop — always honoured (no min-duration block on Flutter side)
  Future<void> requestStop({Function(String path)? onSaved}) async {
    if (!_isRecording) return;
    await _stop(onSaved: onSaved);
  }

  /// Force stop
  Future<void> forceStop({Function(String path)? onSaved}) async {
    if (!_isRecording) return;
    await _stop(onSaved: onSaved);
  }

  Future<void> _stop({Function(String path)? onSaved}) async {
    try {
      final savedPath = await _channel.invokeMethod<String>('stopRecording');
      _isRecording = false;
      final path = savedPath ?? _currentFilePath;
      if (path != null) {
        print("[Recording] SAVED: $path");
        onSaved?.call(path);
      }
    } on PlatformException catch (e) {
      _isRecording = false;
      print("[Recording] Stop error: ${e.message}");
    } catch (e) {
      _isRecording = false;
      print("[Recording] Stop error: $e");
    }
  }

  bool get isRecording => _isRecording;
  String? get currentFilePath => _currentFilePath;

  void dispose() {
    if (_isRecording) {
      _channel.invokeMethod('stopRecording').catchError((_) {});
    }
  }
}

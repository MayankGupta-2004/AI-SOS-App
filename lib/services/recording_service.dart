import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// RecordingService — Audio recording via native MethodChannel
///
/// ✅ FIXED: startRecording now works from Flutter side (manual SOS)
/// ✅ Works for both keyword-triggered and manual SOS
/// ✅ Native KavachService handles the actual MediaRecorder

class RecordingService {
  static const _channel = MethodChannel('com.example.mobile_app/recorder');

  bool _isRecording = false;
  String? _currentFilePath;

  /// Start recording — works from Flutter side now
  Future<void> startRecording({Function(String path)? onSaved}) async {
    if (_isRecording) {
      debugPrint("[Recording] Already recording");
      return;
    }

    try {
      debugPrint("[Recording] Starting via native service...");

      // ✅ FIXED: native side now handles this properly
      // Returns path if recording started, null if failed
      final path = await _channel.invokeMethod<String?>('startRecording');

      if (path == null) {
        debugPrint(
            "[Recording] ⚠️ No path returned — recording may have failed");
        return;
      }

      _currentFilePath = path;
      _isRecording = true;
      debugPrint("[Recording] ✅ STARTED: $path");
      onSaved?.call(path);
    } on PlatformException catch (e) {
      debugPrint("[Recording] ❌ Platform error: ${e.code} — ${e.message}");
    } on MissingPluginException {
      debugPrint(
          "[Recording] ⚠️ Native recording not available on ${Platform.operatingSystem}");
    } catch (e) {
      debugPrint("[Recording] ❌ Error: $e");
    }
  }

  Future<void> requestStop({Function(String path)? onSaved}) async {
    await _stop(onSaved: onSaved);
  }

  Future<void> forceStop({Function(String path)? onSaved}) async {
    await _stop(onSaved: onSaved);
  }

  Future<void> _stop({Function(String path)? onSaved}) async {
    if (!_isRecording) return;

    try {
      final savedPath = await _channel.invokeMethod<String?>('stopRecording');
      _isRecording = false;
      final path = savedPath ?? _currentFilePath;
      if (path != null) {
        debugPrint("[Recording] ✅ SAVED: $path");
        onSaved?.call(path);
      }
    } on PlatformException catch (e) {
      _isRecording = false;
      debugPrint("[Recording] ❌ Stop error: ${e.message}");
    } on MissingPluginException {
      _isRecording = false;
      debugPrint("[Recording] ⚠️ Native stop not available");
    } catch (e) {
      _isRecording = false;
      debugPrint("[Recording] ❌ Error: $e");
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

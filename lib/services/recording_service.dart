import 'dart:async';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

/// RecordingService — Records audio for minimum 10 minutes after SOS.
///
/// SAVE LOCATION: /sdcard/Android/data/com.example.mobile_app/files/
/// (External storage — you can browse this with a file manager app)
///
/// Cannot be stopped before 10 minutes — protects evidence recording.

class RecordingService {
  final AudioRecorder _recorder = AudioRecorder();

  bool _isRecording = false;
  String? _currentFilePath;
  Timer? _minDurationTimer;
  bool _minDurationReached = false;

  static const Duration _minDuration = Duration(minutes: 10);

  /// Start 10-minute background recording
  Future<void> startRecording({Function(String path)? onSaved}) async {
    if (_isRecording) {
      print("[Recording] ⚠️ Already recording");
      return;
    }

    // Check mic permission
    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission) {
      print("[Recording] ❌ No microphone permission");
      return;
    }

    try {
      // Use external storage so file is findable via file manager
      // Falls back to internal if external not available
      String dirPath;
      try {
        final externalDir = await getExternalStorageDirectory();
        dirPath = externalDir!.path;
      } catch (_) {
        final internalDir = await getApplicationDocumentsDirectory();
        dirPath = internalDir.path;
      }

      // Create recordings folder
      final recordingsDir = Directory('$dirPath/KavachRecordings');
      if (!await recordingsDir.exists()) {
        await recordingsDir.create(recursive: true);
      }

      // Filename with timestamp
      final now = DateTime.now();
      final filename = 'SOS_${now.year}-${now.month.toString().padLeft(2, '0')}'
          '-${now.day.toString().padLeft(2, '0')}'
          '_${now.hour.toString().padLeft(2, '0')}'
          '-${now.minute.toString().padLeft(2, '0')}'
          '-${now.second.toString().padLeft(2, '0')}.m4a';

      _currentFilePath = '${recordingsDir.path}/$filename';

      print("[Recording] 📁 Save path: $_currentFilePath");

      // Start recording
      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          sampleRate: 16000,
          numChannels: 1,
          bitRate: 64000,
        ),
        path: _currentFilePath!,
      );

      _isRecording = true;
      _minDurationReached = false;

      print("[Recording] 🎙️ Recording STARTED");
      print(
          "[Recording] ⏱️ Minimum duration: ${_minDuration.inMinutes} minutes");
      print(
          "[Recording] ⚠️ Recording CANNOT be stopped before ${_minDuration.inMinutes} min");

      // Set minimum duration guard
      _minDurationTimer = Timer(_minDuration, () {
        _minDurationReached = true;
        print("[Recording] ✅ Minimum duration reached — can now stop");
      });

      // Auto-stop at exactly 10 minutes + 5 seconds
      Timer(_minDuration + const Duration(seconds: 5), () async {
        if (_isRecording) {
          print("[Recording] ⏰ Auto-stopping at 10 min mark");
          await _stopAndSave(onSaved: onSaved);
        }
      });
    } catch (e) {
      _isRecording = false;
      print("[Recording] ❌ Start failed: $e");
    }
  }

  /// Request stop — silently ignored if min duration not reached
  Future<void> requestStop({Function(String path)? onSaved}) async {
    if (!_isRecording) return;

    if (!_minDurationReached) {
      print("[Recording] 🔒 Stop BLOCKED — min duration not reached yet");
      return;
    }

    await _stopAndSave(onSaved: onSaved);
  }

  /// Force stop — only for app teardown
  Future<void> forceStop({Function(String path)? onSaved}) async {
    _minDurationTimer?.cancel();
    _minDurationReached = true;
    await _stopAndSave(onSaved: onSaved);
  }

  Future<void> _stopAndSave({Function(String path)? onSaved}) async {
    if (!_isRecording) return;

    try {
      _minDurationTimer?.cancel();
      final path = await _recorder.stop();
      _isRecording = false;

      if (path != null) {
        final file = File(path);
        if (await file.exists()) {
          final bytes = await file.length();
          final mb = (bytes / 1024 / 1024).toStringAsFixed(2);
          print("[Recording] 💾 SAVED: $path");
          print("[Recording] 📦 File size: $mb MB");
          onSaved?.call(path);
        } else {
          print("[Recording] ⚠️ File not found after recording: $path");
        }
      }
    } catch (e) {
      print("[Recording] ❌ Stop error: $e");
    }
  }

  bool get isRecording => _isRecording;
  String? get currentFilePath => _currentFilePath;

  void dispose() {
    _minDurationTimer?.cancel();
    _recorder.dispose();
  }
}

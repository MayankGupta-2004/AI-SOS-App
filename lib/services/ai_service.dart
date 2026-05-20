import 'package:flutter/foundation.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

/// AIService — Manages both TFLite models.
///
/// ✅ LAYER 1 (Wake Word Detection via TFLite)
///    Detects distress keywords from MFCC audio features
///
/// ✅ LAYER 2 (Distress Sound Detection via TFLite)
///    Detects gunshot (class 6) and siren (class 8) from audio spectrogram
///
/// ✅ FIXED: removed unused dart:typed_data import
/// ✅ FIXED: all print() → debugPrint()

class AIService {
  Interpreter? wakeWordInterpreter;
  Interpreter? distressInterpreter;

  bool _wakeWordReady = false;
  bool _distressReady = false;

  bool get isWakeWordReady => _wakeWordReady;
  bool get isDistressReady => _distressReady;
  bool get isAnyModelReady => _wakeWordReady || _distressReady;

  /// Initialize both AI models
  Future<void> initModels() async {
    // Load wake word model
    try {
      wakeWordInterpreter =
          await Interpreter.fromAsset('assets/models/distress_model.tflite');
      _wakeWordReady = true;
      _logModelShapes('WakeWord', wakeWordInterpreter!);
    } catch (e) {
      _wakeWordReady = false;
      debugPrint("[AIService] ⚠️ Wake word model load failed: $e");
    }

    // Load distress sound model
    try {
      distressInterpreter =
          await Interpreter.fromAsset('assets/models/sound_model.tflite');
      _distressReady = true;
      _logModelShapes('Distress', distressInterpreter!);
    } catch (e) {
      _distressReady = false;
      debugPrint("[AIService] ⚠️ Distress model load failed: $e");
    }

    if (_wakeWordReady || _distressReady) {
      debugPrint(
          "[AIService] ✅ Models loaded — WakeWord: $_wakeWordReady, Distress: $_distressReady");
    } else {
      debugPrint("[AIService] ❌ No models loaded — AI features disabled");
    }
  }

  void _logModelShapes(String name, Interpreter interpreter) {
    debugPrint(
        "[AIService] $name input: ${interpreter.getInputTensor(0).shape}");
    debugPrint(
        "[AIService] $name output: ${interpreter.getOutputTensor(0).shape}");
  }

  // ─────────────────────────────────────────────────────────────
  // LAYER 1 — WAKE WORD DETECTION
  // Input: [1, 40, 44, 1] — MFCC features
  // Output: [1, 2] — [normal_prob, distress_prob]
  // Returns true if distress probability > 0.85
  // ─────────────────────────────────────────────────────────────
  bool detectWakeWord(List<List<double>> mfcc) {
    if (!_wakeWordReady || wakeWordInterpreter == null) {
      debugPrint("[AIService] ⚠️ Wake word model not ready");
      return false;
    }

    try {
      var input = List.generate(
        1,
        (_) => List.generate(
          40,
          (i) => List.generate(44, (j) {
            if (i < mfcc.length && j < mfcc[i].length) return [mfcc[i][j]];
            return [0.0];
          }),
        ),
      );

      var output = List.generate(1, (_) => List.filled(2, 0.0));
      wakeWordInterpreter!.run(input, output);

      final normalProb = output[0][0];
      final distressProb = output[0][1];
      debugPrint(
          "[AIService] WakeWord — normal: ${normalProb.toStringAsFixed(3)}, distress: ${distressProb.toStringAsFixed(3)}");

      return distressProb > 0.85;
    } catch (e) {
      debugPrint("[AIService] ❌ Wake word inference error: $e");
      return false;
    }
  }

  // ─────────────────────────────────────────────────────────────
  // LAYER 2 — DISTRESS SOUND DETECTION
  // Input: [1, 64, 174, 1] — Mel spectrogram
  // Output: [1, 10] — probability per class
  // Returns true if gunshot (class 6) > 0.6 or siren (class 8) > 0.6
  // ─────────────────────────────────────────────────────────────
  bool detectDistress(List<List<double>> spectrogram) {
    if (!_distressReady || distressInterpreter == null) {
      debugPrint("[AIService] ⚠️ Distress model not ready");
      return false;
    }

    try {
      var input = List.generate(
        1,
        (_) => List.generate(
          64,
          (i) => List.generate(174, (j) {
            if (i < spectrogram.length && j < spectrogram[i].length) {
              return [spectrogram[i][j]];
            }
            return [0.0];
          }),
        ),
      );

      var output = List.generate(1, (_) => List.filled(10, 0.0));
      distressInterpreter!.run(input, output);

      final probs = output[0];
      final gunshot = probs.length > 6 ? probs[6] : 0.0;
      final siren = probs.length > 8 ? probs[8] : 0.0;

      debugPrint(
          "[AIService] Distress — gunshot: ${gunshot.toStringAsFixed(3)}, siren: ${siren.toStringAsFixed(3)}");

      return gunshot > 0.6 || siren > 0.6;
    } catch (e) {
      debugPrint("[AIService] ❌ Distress inference error: $e");
      return false;
    }
  }

  String getStatusText() {
    if (_wakeWordReady && _distressReady) return 'AI Models: Both Active ✅';
    if (_wakeWordReady) return 'AI: Wake Word Active ✅ | Distress ❌';
    if (_distressReady) return 'AI: Wake Word ❌ | Distress Active ✅';
    return 'AI Models: Unavailable ❌';
  }

  void dispose() {
    wakeWordInterpreter?.close();
    distressInterpreter?.close();
  }
}

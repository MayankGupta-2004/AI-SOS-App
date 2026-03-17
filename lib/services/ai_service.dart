import 'package:tflite_flutter/tflite_flutter.dart';

/// AIService — Manages both TFLite models.
///
/// ⚠️ LAYER 1 (Wake Word via TFLite) — COMMENTED OUT
///    Replaced by: speech_to_text keyword detection in KavachListener
///
/// ⚠️ LAYER 2 (Distress Sound Detection via TFLite) — COMMENTED OUT
///    Reason: Being rebuilt with improved audio pipeline
///    Both models are still loaded and ready for future re-integration.

class AIService {
  Interpreter? wakeWordInterpreter;
  Interpreter? distressInterpreter;

  Future<void> initModels() async {
    try {
      // Load wake word model (distress_model.tflite → input: [1, 40, 44, 1])
      wakeWordInterpreter =
          await Interpreter.fromAsset('assets/models/distress_model.tflite');

      // Load distress sound model (sound_model.tflite → input: [1, 64, 174, 1])
      distressInterpreter =
          await Interpreter.fromAsset('assets/models/sound_model.tflite');

      print("[AIService] ✅ Models loaded successfully");
      print(
          "[AIService] WakeWord input: ${wakeWordInterpreter!.getInputTensor(0).shape}");
      print(
          "[AIService] Distress input: ${distressInterpreter!.getInputTensor(0).shape}");
    } catch (e) {
      print("[AIService] ⚠️ Model load failed: $e");
    }
  }

  // -----------------------------------------------------------------------
  // LAYER 1 — WAKE WORD DETECTION (TFLite) — DISABLED
  // -----------------------------------------------------------------------
  // Replaced by speech_to_text keyword matching in KavachListener.
  // Uncomment and wire back in when TFLite wake-word pipeline is ready.
  //
  // bool detectWakeWord(List<List<double>> mfcc) {
  //   var input = List.generate(
  //     1,
  //     (_) => List.generate(
  //       40,
  //       (i) => List.generate(44, (j) => [mfcc[i][j]]),
  //     ),
  //   );
  //   var output = List.generate(1, (_) => List.filled(2, 0.0));
  //   wakeWordInterpreter!.run(input, output);
  //   double probability = output[0][1];
  //   print("[AIService] WakeWord probability: $probability");
  //   return probability > 0.98;
  // }
  // -----------------------------------------------------------------------

  // -----------------------------------------------------------------------
  // LAYER 2 — DISTRESS SOUND DETECTION (TFLite) — DISABLED
  // -----------------------------------------------------------------------
  // Will detect gunshot (class 6) and siren (class 8) from audio spectrogram.
  // Uncomment when audio pipeline feeds clean 5-second PCM16 buffers.
  //
  // bool detectDistress(List<List<double>> spectrogram) {
  //   var input = List.generate(
  //     1,
  //     (_) => List.generate(
  //       64,
  //       (i) => List.generate(174, (j) => [spectrogram[i][j]]),
  //     ),
  //   );
  //   var output = List.generate(1, (_) => List.filled(10, 0.0));
  //   distressInterpreter!.run(input, output);
  //   List<double> probs = output[0];
  //   double gunshot = probs[6];
  //   double siren   = probs[8];
  //   print("[AIService] gunshot: $gunshot | siren: $siren");
  //   return gunshot > 0.6 || siren > 0.6;
  // }
  // -----------------------------------------------------------------------
}

import 'dart:async';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_to_text.dart';

import 'sos_service.dart';
import 'siren_service.dart';
import 'recording_service.dart';
import 'contact_service.dart';

/// KavachListener — Full protection mode controller.
///
/// FLOW:
/// [Protection ON] → Layer 1: speech_to_text keyword loop
///                       ↓ keyword/button
///                   Layer 2: stop speech → siren → SMS+server → recording

class KavachListener {
  final SpeechToText _speech = SpeechToText();

  final SOSService sosService;
  final SirenService sirenService;
  final RecordingService recordingService;
  final ContactService contactService;

  bool _protectionMode = false;
  bool _sosTriggered = false;
  bool _speechInitialized = false;
  bool _isListening = false;

  Function(String status)? onStatusUpdate;
  Function(bool sosActive)? onSosStateChange;

  static const List<String> _keywords = [
    'help',
    'help me',
    'save me',
    'bachao',
    'koi bachao',
    'bacchao',
    'mujhe bachao',
    'madad',
    'madad karo',
    'somebody help',
    'please help',
    'emergency',
    'danger',
    'help help',
    'sos',
  ];

  KavachListener({
    required this.sosService,
    required this.sirenService,
    required this.recordingService,
    required this.contactService,
    this.onStatusUpdate,
    this.onSosStateChange,
  });

  // ═══════════════════════════════════════════════════════
  // START PROTECTION MODE
  // ═══════════════════════════════════════════════════════

  Future<bool> startProtection() async {
    if (_protectionMode) return true;

    // ── Check mic permission explicitly ──────────────────
    final micStatus = await Permission.microphone.status;
    if (!micStatus.isGranted) {
      final result = await Permission.microphone.request();
      if (!result.isGranted) {
        print("[Kavach] ❌ Microphone permission denied");
        onStatusUpdate?.call('❌ Microphone permission denied. Go to Settings.');
        return false;
      }
    }

    print("[Kavach] 🛡️ Starting protection mode");
    onStatusUpdate?.call('Starting speech recognition...');

    // ── Initialize speech engine ─────────────────────────
    if (!_speechInitialized) {
      _speechInitialized = await _speech.initialize(
        onStatus: (status) {
          print("[Kavach] Speech status: $status");
          _isListening = _speech.isListening;

          // Auto-restart when session ends naturally
          if (_protectionMode && !_sosTriggered) {
            if (status == SpeechToText.doneStatus ||
                status == SpeechToText.notListeningStatus) {
              Future.delayed(const Duration(milliseconds: 300), _startLayer1);
            }
          }
        },
        onError: (error) {
          print(
              "[Kavach] Speech error: ${error.errorMsg} (permanent: ${error.permanent})");
          _isListening = false;

          if (_protectionMode && !_sosTriggered) {
            // Permanent errors need re-init
            if (error.permanent) {
              _speechInitialized = false;
            }
            Future.delayed(const Duration(seconds: 1), _startLayer1);
          }
        },
      );
    }

    if (!_speechInitialized) {
      print("[Kavach] ❌ Speech init failed");
      onStatusUpdate
          ?.call('❌ Speech recognition failed. Check mic permission.');
      return false;
    }

    _protectionMode = true;
    _sosTriggered = false;
    _startLayer1();
    return true;
  }

  // ═══════════════════════════════════════════════════════
  // LAYER 1 — KEYWORD LISTENING LOOP
  // Restarts itself automatically
  // ═══════════════════════════════════════════════════════

  Future<void> _startLayer1() async {
    if (!_protectionMode || _sosTriggered || !_speechInitialized) return;
    if (_speech.isListening) return; // already running

    print("[Kavach] 👂 Layer 1: keyword listening active");
    onStatusUpdate?.call('👂 Listening for distress keywords...');

    try {
      await _speech.listen(
        listenMode: ListenMode.dictation,
        partialResults: true,
        listenFor: const Duration(seconds: 30),
        pauseFor: const Duration(seconds: 5),
        onResult: (result) {
          final words = result.recognizedWords.toLowerCase().trim();
          if (words.isEmpty) return;

          print("[Kavach] Heard: '$words'");

          for (final kw in _keywords) {
            if (words.contains(kw)) {
              print("[Kavach] 🚨 KEYWORD: '$kw'");
              _triggerLayer2();
              return;
            }
          }
        },
      );
    } catch (e) {
      print("[Kavach] Listen error: $e");
      if (_protectionMode && !_sosTriggered) {
        Future.delayed(const Duration(seconds: 2), _startLayer1);
      }
    }
  }

  // ═══════════════════════════════════════════════════════
  // LAYER 2 — FULL SOS SEQUENCE
  // ═══════════════════════════════════════════════════════

  Future<void> _triggerLayer2() async {
    if (_sosTriggered) return;
    _sosTriggered = true;
    onSosStateChange?.call(true);

    print("[Kavach] ══════════════════════════════════");
    print("[Kavach] 🚨 LAYER 2 — SOS SEQUENCE START");
    print("[Kavach] ══════════════════════════════════");

    // STEP 1 — Stop speech recognition
    print("[Kavach] STEP 1: Stopping speech recognition");
    onStatusUpdate?.call('🚨 SOS — Stopping mic...');
    try {
      await _speech.stop();
    } catch (e) {
      print("[Kavach] Speech stop error (non-fatal): $e");
    }
    print("[Kavach] ✅ Speech stopped");

    // STEP 2 — Start siren
    print("[Kavach] STEP 2: Starting siren");
    onStatusUpdate?.call('🔊 Siren ON...');
    await sirenService.startSiren();
    print("[Kavach] ✅ Siren playing");

    // STEP 3+4 — Send SMS + ping server (parallel)
    print("[Kavach] STEP 3+4: Sending SMS + server ping");
    onStatusUpdate?.call(
        '📤 Sending SOS to ${contactService.contacts.length} contacts...');
    await sosService.sendSOS(contactService);
    print("[Kavach] ✅ SMS sent + server pinged");

    // STEP 5 — Start 10-min background recording
    print("[Kavach] STEP 5: Starting 10-min background recording");
    onStatusUpdate?.call('🎙️ Recording started (10 min)...');
    await recordingService.startRecording(
      onSaved: (path) {
        print("[Kavach] 💾 Recording saved: $path");
        onStatusUpdate?.call('✅ Recording saved to phone');
      },
    );
    print("[Kavach] ✅ Recording running");

    print("[Kavach] ══════════════════════════════════");
    print("[Kavach] ✅ FULL SOS SEQUENCE COMPLETE");
    print("[Kavach] ══════════════════════════════════");
    onStatusUpdate?.call('🚨 SOS Active | Recording in background');
  }

  // ═══════════════════════════════════════════════════════
  // MANUAL SOS — Kavach button
  // ═══════════════════════════════════════════════════════

  Future<void> manualSOS() async {
    print("[Kavach] 🔴 Manual SOS triggered");
    await _triggerLayer2();
  }

  // ═══════════════════════════════════════════════════════
  // STOP SOS — siren off, recording continues
  // ═══════════════════════════════════════════════════════

  Future<void> stopSOS() async {
    if (!_sosTriggered) return;

    await sirenService.stopSiren();
    _sosTriggered = false;
    onSosStateChange?.call(false);

    print("[Kavach] Siren OFF. Recording continues in background.");

    if (_protectionMode) {
      Future.delayed(const Duration(seconds: 2), _startLayer1);
    }

    onStatusUpdate?.call(
      _protectionMode ? '👂 Listening for keywords...' : 'Protection mode OFF',
    );
  }

  // ═══════════════════════════════════════════════════════
  // STOP PROTECTION MODE
  // ═══════════════════════════════════════════════════════

  Future<void> stopProtection() async {
    _protectionMode = false;
    _sosTriggered = false;

    try {
      await _speech.stop();
    } catch (_) {}
    await sirenService.stopSiren();

    onSosStateChange?.call(false);
    onStatusUpdate?.call('Protection mode OFF');
    print("[Kavach] 🛡️ Protection mode OFF");
  }

  bool get isProtectionActive => _protectionMode;
  bool get isSosActive => _sosTriggered;
}

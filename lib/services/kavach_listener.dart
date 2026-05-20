import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import 'notification_service.dart';
import 'sos_service.dart';
import 'siren_service.dart';
import 'recording_service.dart';
import 'contact_service.dart';

/// KavachListener — Voice detection + SOS sequence
///
/// ARCHITECTURE:
/// ─────────────────────────────────────────────────────────────
/// Primary detection: KavachService (native Android, always on)
///   → Runs in foreground service, survives screen lock + app kill
///   → Detects keywords, sends callback to Flutter via MethodChannel
///   → Flutter shows countdown dialog, handles full SOS sequence
///
/// Secondary detection: Flutter speech_to_text (when app in foreground)
///   → Provides additional multilingual detection layer
///   → Uses device's default locale — NO cycling (avoids crashes)
///   → If locale not installed, gracefully falls back to en-IN
///
/// SOS sequence (same for voice + manual):
///   countdown → siren → SMS → server → recording (10 min)
/// ─────────────────────────────────────────────────────────────

class KavachListener {
  final stt.SpeechToText _speech = stt.SpeechToText();
  static const _speechChannel = MethodChannel('com.example.mobile_app/speech');

  final NotificationService _notif = NotificationService();

  final SOSService sosService;
  final SirenService sirenService;
  final RecordingService recordingService;
  final ContactService contactService;

  bool _protectionMode = false;
  bool _sosTriggered = false;
  bool _speechAvailable = false;
  bool _isCountingDown = false;
  Timer? _countdownTimer;
  Timer? _listenRestartTimer;

  // ── KEYWORDS — all major Indian languages ────────────────────
  static const List<String> _keywords = [
    // English
    'help', 'help me', 'save me', 'somebody help', 'please help',
    'help help', 'call police',
    // Hindi Roman
    'bachao', 'koi bachao', 'bacchao', 'mujhe bachao',
    'madad', 'madad karo',
    // Hindi Devanagari
    'बचाओ', 'कोई बचाओ', 'मुझे बचाओ', 'मदद', 'मदद करो',
    'मुझे मदद चाहिए', 'सहायता', 'खतरा', 'इमरजेंसी', 'हेल्प',
    // Tamil Roman
    'udavi', 'udavungal', 'kaaparu', 'aapathu',
    // Tamil script
    'உதவி', 'உதவுங்கள்',
    // Telugu Roman
    'sahayam', 'pramaadam', 'rakshimchu',
    // Telugu script
    'సహాయం', 'ప్రమాదం',
    // Bengali Roman
    'shahajjo', 'bipod',
    // Bengali script
    'সাহায্য', 'বাঁচাও',
    // Marathi
    'madat', 'vachava', 'dhoka',
    'मदत', 'वाचवा',
    // Gujarati
    'bachavo', 'bhay',
    'મદદ', 'બચાવો',
    // Kannada
    'sahaya', 'ulisi',
    'ಸಹಾಯ', 'ಉಳಿಸಿ',
    // Malayalam
    'sahaayam', 'rakshikkoo',
    'സഹായം', 'രക്ഷിക്കൂ',
    // Punjabi
    'khatra',
    'ਮਦਦ', 'ਬਚਾਓ',
  ];

  // Callbacks to HomeScreen
  Function(String status)? onStatusUpdate;
  Function(bool sosActive)? onSosStateChange;
  Function(int seconds)? onCountdownTick;
  Function()? onCountdownStart;
  Function()? onCountdownCancel;

  KavachListener({
    required this.sosService,
    required this.sirenService,
    required this.recordingService,
    required this.contactService,
    this.onStatusUpdate,
    this.onSosStateChange,
    this.onCountdownTick,
    this.onCountdownStart,
    this.onCountdownCancel,
  }) {
    // ── Native Android keyword callback ──────────────────────
    // KavachService runs always — even when screen locked or app killed
    // When it detects a keyword, it sends this callback to Flutter
    if (Platform.isAndroid) {
      _speechChannel.setMethodCallHandler((call) async {
        switch (call.method) {
          case 'onKeywordDetected':
            final keyword = call.arguments as String? ?? '';
            debugPrint("[Kavach] 🎤 Native keyword: '$keyword'");
            if (_protectionMode && !_sosTriggered && !_isCountingDown) {
              // When screen is locked, skip countdown and fire immediately
              // (user can't see/tap a dialog when screen is off)
              await _startCountdown(source: 'native-$keyword');
            }
            break;
          case 'onStatusUpdate':
            final status = call.arguments as String? ?? '';
            if (status == 'listening' && _protectionMode && !_sosTriggered) {
              onStatusUpdate?.call('👂 सुन रहा हूँ... Listening...');
            }
            break;
        }
      });
    }
  }

  // ── START PROTECTION ──────────────────────────────────────────

  Future<bool> startProtection() async {
    if (_protectionMode) return true;
    debugPrint("[Kavach] 🛡️ Starting protection");
    onStatusUpdate?.call('Starting protection mode...');

    try {
      // Try to init Flutter STT (secondary layer, app foreground only)
      _speechAvailable = await _speech.initialize(
        onStatus: (status) {
          debugPrint("[Kavach] STT status: $status");
          if ((status == 'done' || status == 'notListening') &&
              _protectionMode &&
              !_sosTriggered &&
              !_isCountingDown) {
            _restartListening();
          }
        },
        onError: (error) {
          debugPrint("[Kavach] STT error: ${error.errorMsg}");
          if (_protectionMode && !_sosTriggered && !_isCountingDown) {
            _restartListening();
          }
        },
      );

      _protectionMode = true;
      _sosTriggered = false;

      if (_speechAvailable) {
        await _startListening();
        debugPrint("[Kavach] ✅ Flutter STT active");
      } else {
        debugPrint("[Kavach] ⚠️ Flutter STT unavailable — native only");
      }

      await _notif.showProtectionOn();
      onStatusUpdate?.call('👂 सुन रहा हूँ... Listening...');
      return true;
    } catch (e) {
      debugPrint("[Kavach] ❌ Protection start failed: $e");
      // Still enable protection — native KavachService handles detection
      _protectionMode = true;
      await _notif.showProtectionOn();
      onStatusUpdate?.call('👂 Listening (native mode)...');
      return true;
    }
  }

  // ── FLUTTER STT LISTENING ────────────────────────────────────
  // Single session, device default locale — no cycling
  // Cycling caused crashes when locales not installed on device

  Future<void> _startListening() async {
    if (!_protectionMode || _sosTriggered || _isCountingDown) return;
    if (!_speechAvailable) return;

    try {
      // ✅ Get available locales and pick the best one
      final locales = await _speech.locales();
      final localeIds = locales.map((l) => l.localeId).toSet();

      // Preferred order — use first available
      final preferred = ['hi-IN', 'en-IN', 'en-US'];
      String locale = 'en-US'; // fallback
      for (final p in preferred) {
        if (localeIds.contains(p)) {
          locale = p;
          break;
        }
      }

      debugPrint("[Kavach] 👂 Flutter STT listening ($locale)");

      await _speech.listen(
        onResult: (result) {
          final text = result.recognizedWords.toLowerCase().trim();
          if (text.isEmpty) return;
          debugPrint("[Kavach] Heard: '$text'");

          if (_containsKeyword(text) && !_sosTriggered && !_isCountingDown) {
            debugPrint("[Kavach] 🚨 KEYWORD: '$text'");
            _startCountdown(source: 'flutter-stt');
          }
        },
        listenFor: const Duration(seconds: 30),
        pauseFor: const Duration(seconds: 5),
        localeId: locale,
        listenOptions: stt.SpeechListenOptions(
          partialResults: true,
          listenMode: stt.ListenMode.dictation,
          cancelOnError: false,
        ),
      );
    } catch (e) {
      debugPrint("[Kavach] ❌ Flutter STT error: $e");
      if (_protectionMode && !_sosTriggered) _restartListening();
    }
  }

  void _restartListening() {
    _listenRestartTimer?.cancel();
    _listenRestartTimer = Timer(const Duration(milliseconds: 600), () {
      if (_protectionMode && !_sosTriggered && !_isCountingDown) {
        _startListening();
      }
    });
  }

  bool _containsKeyword(String text) {
    return _keywords.any((kw) => text.contains(kw.toLowerCase()));
  }

  // ── 3-SECOND COUNTDOWN ───────────────────────────────────────

  Future<void> _startCountdown({required String source}) async {
    if (_isCountingDown || _sosTriggered) return;
    _isCountingDown = true;

    debugPrint("[Kavach] ⏳ 3s countdown (source: $source)");
    onCountdownStart?.call();
    onStatusUpdate?.call('⚠️ SOS in 3 seconds... Tap to cancel');

    int remaining = 3;
    onCountdownTick?.call(remaining);

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      remaining--;
      onCountdownTick?.call(remaining);
      onStatusUpdate?.call('⚠️ SOS in $remaining seconds... Tap to cancel');

      if (remaining <= 0) {
        timer.cancel();
        _isCountingDown = false;
        await _handleSOSTrigger();
      }
    });
  }

  void cancelCountdown() {
    if (!_isCountingDown) return;
    _countdownTimer?.cancel();
    _isCountingDown = false;
    onCountdownCancel?.call();
    onStatusUpdate?.call('✅ SOS cancelled — still listening');
    debugPrint("[Kavach] ✅ Countdown cancelled");

    if (_protectionMode && !_sosTriggered) {
      Future.delayed(const Duration(milliseconds: 800), () {
        onStatusUpdate?.call('👂 सुन रहा हूँ... Listening...');
        if (_speechAvailable) _startListening();
      });
    }
  }

  // ── FULL SOS SEQUENCE ─────────────────────────────────────────
  // Identical for voice trigger AND manual button

  Future<void> _handleSOSTrigger() async {
    if (_sosTriggered) return;
    _sosTriggered = true;
    onSosStateChange?.call(true);
    debugPrint("[Kavach] 🚨 SOS SEQUENCE START");
    onStatusUpdate?.call('🚨 SOS triggered!');

    // 1. Stop Flutter STT
    try {
      await _speech.stop();
    } catch (_) {}

    // 2. Siren ON
    try {
      await sirenService.startSiren();
    } catch (e) {
      debugPrint("[Kavach] ⚠️ Siren: $e");
    }

    // 3. SOS notification
    try {
      await _notif.showSOSTriggered();
    } catch (e) {
      debugPrint("[Kavach] ⚠️ Notif: $e");
    }

    // 4. Send SMS + ping server
    onStatusUpdate?.call('📤 Sending SOS alerts...');
    try {
      await sosService.sendSOS(contactService);
    } catch (e) {
      debugPrint("[Kavach] ⚠️ SMS/server: $e");
    }

    // 5. Start 10-min recording
    try {
      await recordingService.startRecording();
      await _notif.showRecordingStarted();
      onStatusUpdate?.call('🎙️ Recording evidence (10 min)');
    } catch (e) {
      debugPrint("[Kavach] ⚠️ Recording: $e");
    }

    debugPrint("[Kavach] ✅ SOS SEQUENCE COMPLETE");
    onStatusUpdate?.call('🚨 SOS Active | Recording in background');
  }

  // ── MANUAL SOS ────────────────────────────────────────────────

  /// Called by KAVACH button press — shows 3s countdown first
  Future<void> manualSOS() async {
    debugPrint("[Kavach] 🔴 Manual SOS — countdown");
    await _startCountdown(source: 'manual');
  }

  /// Called by HomeScreen after countdown completes
  Future<void> immediateManualSOS() async {
    debugPrint("[Kavach] 🔴 IMMEDIATE SOS");
    _countdownTimer?.cancel();
    _isCountingDown = false;
    await _handleSOSTrigger();
  }

  // ── STOP SOS ──────────────────────────────────────────────────

  Future<void> stopSOS() async {
    if (!_sosTriggered) return;
    try {
      await sirenService.stopSiren();
    } catch (e) {
      debugPrint("[Kavach] ⚠️ Stop siren: $e");
    }
    try {
      await _notif.showSOSStopped();
    } catch (e) {
      debugPrint("[Kavach] ⚠️ Notif: $e");
    }

    _sosTriggered = false;
    onSosStateChange?.call(false);
    debugPrint("[Kavach] Siren OFF. Recording continues 10 min.");
    onStatusUpdate?.call('🎙️ Recording continues in background...');
  }

  // ── STOP PROTECTION ───────────────────────────────────────────

  Future<void> stopProtection() async {
    _protectionMode = false;
    _sosTriggered = false;
    _isCountingDown = false;
    _countdownTimer?.cancel();
    _listenRestartTimer?.cancel();

    try {
      await _speech.stop();
    } catch (_) {}

    if (Platform.isAndroid) {
      try {
        await _speechChannel.invokeMethod('stopListening');
      } catch (_) {}
    }

    try {
      await sirenService.stopSiren();
    } catch (_) {}

    try {
      await _notif.showProtectionOff();
      Future.delayed(const Duration(seconds: 3), () => _notif.cancelAll());
    } catch (_) {}

    onSosStateChange?.call(false);
    onStatusUpdate?.call('Protection mode OFF');
    debugPrint("[Kavach] 🛡️ Protection OFF");
  }

  bool get isProtectionActive => _protectionMode;
  bool get isSosActive => _sosTriggered;
  bool get isCountingDown => _isCountingDown;

  /// Stops only Flutter STT — native KavachService keeps listening
  /// Called when app goes to background, NOT when user taps stop
  Future<void> stopFlutterSTTOnly() async {
    try {
      await _speech.stop();
    } catch (_) {}
    debugPrint("[Kavach] Flutter STT stopped — native continues");
  }
}

import 'package:flutter/services.dart';

import 'notification_service.dart';
import 'sos_service.dart';
import 'siren_service.dart';
import 'recording_service.dart';
import 'contact_service.dart';

/// KavachListener
///
/// Recording is 100% native — KavachService.kt handles it.
/// Flutter only handles: siren, SMS, notifications, UI.
/// Flutter NEVER starts or stops recording directly.

class KavachListener {
  static const _speechChannel = MethodChannel('com.example.mobile_app/speech');
  static const _recordChannel =
      MethodChannel('com.example.mobile_app/recorder');

  final NotificationService _notif = NotificationService();

  final SOSService sosService;
  final SirenService sirenService;
  final RecordingService recordingService;
  final ContactService contactService;

  bool _protectionMode = false;
  bool _sosTriggered = false;

  Function(String status)? onStatusUpdate;
  Function(bool sosActive)? onSosStateChange;

  KavachListener({
    required this.sosService,
    required this.sirenService,
    required this.recordingService,
    required this.contactService,
    this.onStatusUpdate,
    this.onSosStateChange,
  }) {
    _speechChannel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'onKeywordDetected':
          final keyword = call.arguments as String? ?? '';
          print("[Kavach] Native keyword: '$keyword'");
          if (_protectionMode && !_sosTriggered) {
            await _handleSOSTrigger();
          }
          break;
        case 'onStatusUpdate':
          final status = call.arguments as String? ?? '';
          if (status == 'listening' && _protectionMode && !_sosTriggered) {
            onStatusUpdate?.call('👂 Listening for distress keywords...');
          }
          break;
      }
    });
  }

  // ── START PROTECTION ──────────────────────────────────────────

  Future<bool> startProtection() async {
    if (_protectionMode) return true;
    print("[Kavach] 🛡️ Starting protection mode");
    onStatusUpdate?.call('Starting protection mode...');
    try {
      await _speechChannel.invokeMethod('startListening');
      _protectionMode = true;
      _sosTriggered = false;
      await _notif.showProtectionOn();
      onStatusUpdate?.call('👂 Listening for distress keywords...');
      print("[Kavach] ✅ Protection mode active");
      return true;
    } on PlatformException catch (e) {
      print("[Kavach] ❌ Failed: ${e.message}");
      return false;
    }
  }

  // ── SOS TRIGGER ───────────────────────────────────────────────

  Future<void> _handleSOSTrigger() async {
    if (_sosTriggered) return;
    _sosTriggered = true;
    onSosStateChange?.call(true);
    print("[Kavach] 🚨 SOS SEQUENCE START");

    // STEP 1 — Stop speech (native already stopped it, this is just Flutter-side cleanup)
    onStatusUpdate?.call('🚨 SOS triggered!');
    try {
      await _speechChannel.invokeMethod('stopListening');
    } catch (_) {}

    // STEP 2 — Siren
    await sirenService.startSiren();
    await _notif.showSOSTriggered();

    // STEP 3 — SMS + server
    onStatusUpdate?.call('📤 Sending SOS...');
    await sosService.sendSOS(contactService);

    // STEP 4 — Recording is ALREADY running natively.
    // Just update the UI — do NOT start a new recording.
    await Future.delayed(const Duration(milliseconds: 500));
    final nativeRecording = await _isNativeRecording();
    if (nativeRecording) {
      print("[Kavach] ✅ Native recording confirmed running");
      await _notif.showRecordingStarted();
      onStatusUpdate?.call('🎙️ Recording in background (10 min)');
    } else {
      print(
          "[Kavach] ⚠️ Native recording not detected — may have started late");
      onStatusUpdate?.call('⚠️ Check recording status');
    }

    print("[Kavach] ✅ SOS SEQUENCE COMPLETE");
    onStatusUpdate?.call('🚨 SOS Active | Recording in background');
  }

  Future<bool> _isNativeRecording() async {
    try {
      return await _recordChannel.invokeMethod<bool>('isRecording') ?? false;
    } catch (_) {
      return false;
    }
  }

  // ── MANUAL SOS BUTTON ─────────────────────────────────────────

  Future<void> manualSOS() async {
    print("[Kavach] 🔴 Manual SOS");
    await _handleSOSTrigger();
  }

  // ── STOP SOS ──────────────────────────────────────────────────

  Future<void> stopSOS() async {
    if (!_sosTriggered) return;
    await sirenService.stopSiren();
    await _notif.showSOSStopped();
    _sosTriggered = false;
    onSosStateChange?.call(false);
    // Recording continues — NEVER stopped here
    print("[Kavach] Siren OFF. Recording continues natively.");
    onStatusUpdate?.call('🎙️ Recording continues in background...');
  }

  // ── STOP PROTECTION ───────────────────────────────────────────

  Future<void> stopProtection() async {
    _protectionMode = false;
    _sosTriggered = false;

    // Only stops speech — recording (if active) keeps running natively
    try {
      await _speechChannel.invokeMethod('stopListening');
    } catch (_) {}
    await sirenService.stopSiren();
    await _notif.showProtectionOff();
    Future.delayed(const Duration(seconds: 3), () => _notif.cancelAll());

    onSosStateChange?.call(false);
    onStatusUpdate?.call('Protection mode OFF');
    print("[Kavach] 🛡️ Protection OFF. Any active recording continues.");
  }

  bool get isProtectionActive => _protectionMode;
  bool get isSosActive => _sosTriggered;
}

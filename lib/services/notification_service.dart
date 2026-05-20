import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// NotificationService — Cross-platform push notifications (Android + iOS)
///
/// Used to notify the user when:
///  - Protection mode starts/stops
///  - SOS is triggered
///  - Countdown is active
///  - Recording starts/saves

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  // Notification IDs
  static const int _protectionId = 1;
  static const int _sosId = 2;
  static const int _recordingId = 3;
  static const int _countdownId = 4;

  /// Call once at app startup
  Future<void> init() async {
    if (_initialized) return;

    try {
      // Android settings
      const androidSettings = AndroidInitializationSettings(
        '@mipmap/ic_launcher',
      );

      // iOS settings
      const iosSettings = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

      const initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );

      await _plugin.initialize(
        initSettings,
        onDidReceiveNotificationResponse: (details) {
          debugPrint('[Notification] Tapped: ${details.payload}');
        },
      );

      // Request notification permission (Android 13+ / iOS)
      if (Platform.isAndroid) {
        await _plugin
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>()
            ?.requestNotificationsPermission();
      } else if (Platform.isIOS) {
        await _plugin
            .resolvePlatformSpecificImplementation<
                IOSFlutterLocalNotificationsPlugin>()
            ?.requestPermissions(alert: true, badge: true, sound: true);
      }

      _initialized = true;
      debugPrint('[Notification] ✅ Initialized (${Platform.operatingSystem})');
    } catch (e) {
      debugPrint('[Notification] ❌ Init failed: $e');
    }
  }

  // ── PROTECTION MODE ON ──────────────────────────────────────────

  Future<void> showProtectionOn() async {
    await _show(
      id: _protectionId,
      title: '🛡️ Kavach Protection Active',
      body:
          'You are now in Protection Mode. Say "help" or "bachao" to trigger SOS.',
      ongoing: true,
      payload: 'protection_on',
    );
  }

  // ── PROTECTION MODE OFF ─────────────────────────────────────────

  Future<void> showProtectionOff() async {
    await _cancel(_protectionId);
    await _show(
      id: _protectionId,
      title: 'Kavach Protection OFF',
      body: 'Protection mode has been turned off.',
      ongoing: false,
      payload: 'protection_off',
    );
  }

  // ── SOS COUNTDOWN ──────────────────────────────────────────────

  Future<void> showCountdown(int seconds) async {
    await _show(
      id: _countdownId,
      title: '⚠️ SOS in $seconds seconds',
      body: 'Tap to open app and cancel if false alarm.',
      ongoing: true,
      payload: 'countdown',
      importance: Importance.max,
      priority: Priority.max,
    );
  }

  Future<void> cancelCountdown() async {
    await _cancel(_countdownId);
  }

  // ── SOS TRIGGERED ───────────────────────────────────────────────

  Future<void> showSOSTriggered() async {
    await _cancel(_countdownId);
    await _show(
      id: _sosId,
      title: '🚨 SOS TRIGGERED',
      body: 'Emergency alert sent! Siren active. SMS sent to your contacts.',
      ongoing: true,
      payload: 'sos_triggered',
      importance: Importance.max,
      priority: Priority.max,
    );
  }

  // ── SOS STOPPED ─────────────────────────────────────────────────

  Future<void> showSOSStopped() async {
    await _cancel(_sosId);
  }

  // ── RECORDING STARTED ───────────────────────────────────────────

  Future<void> showRecordingStarted() async {
    await _show(
      id: _recordingId,
      title: '🎙️ Recording in Progress',
      body:
          'Background audio recording started (10 min). Do not close the app.',
      ongoing: true,
      payload: 'recording_started',
    );
  }

  // ── RECORDING SAVED ─────────────────────────────────────────────

  Future<void> showRecordingSaved(String path) async {
    await _cancel(_recordingId);
    await _show(
      id: _recordingId,
      title: '💾 Recording Saved',
      body: 'Audio evidence saved to KavachRecordings folder.',
      ongoing: false,
      payload: 'recording_saved',
    );
  }

  // ── INTERNAL SHOW ───────────────────────────────────────────────

  Future<void> _show({
    required int id,
    required String title,
    required String body,
    required bool ongoing,
    String? payload,
    Importance importance = Importance.high,
    Priority priority = Priority.high,
  }) async {
    if (!_initialized) {
      try {
        await init();
      } catch (_) {
        return;
      }
    }

    try {
      final androidDetails = AndroidNotificationDetails(
        'kavach_channel',
        'Kavach Alerts',
        channelDescription: 'Kavach SOS protection alerts',
        importance: importance,
        priority: priority,
        ongoing: ongoing,
        autoCancel: !ongoing,
        playSound: false,
        icon: '@mipmap/ic_launcher',
      );

      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: false,
      );

      final details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await _plugin.show(id, title, body, details, payload: payload);
      debugPrint('[Notification] Shown: $title');
    } catch (e) {
      debugPrint('[Notification] ❌ Show error: $e');
    }
  }

  Future<void> _cancel(int id) async {
    try {
      await _plugin.cancel(id);
    } catch (e) {
      debugPrint('[Notification] ❌ Cancel error: $e');
    }
  }

  Future<void> cancelAll() async {
    try {
      await _plugin.cancelAll();
    } catch (e) {
      debugPrint('[Notification] ❌ CancelAll error: $e');
    }
  }
}

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// NotificationService — shows local push notifications.
///
/// Used to notify the user when:
///  - Protection mode starts
///  - Protection mode stops
///  - SOS is triggered
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

  /// Call once at app startup
  Future<void> init() async {
    if (_initialized) return;

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher', // uses your existing app icon
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
    );

    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (details) {
        // Handle tap on notification if needed
        print("[Notification] Tapped: ${details.payload}");
      },
    );

    // Request notification permission (Android 13+)
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();

    _initialized = true;
    print("[Notification] Initialized");
  }

  // ── PROTECTION MODE ON ──────────────────────────────────────────

  Future<void> showProtectionOn() async {
    await _show(
      id: _protectionId,
      title: '🛡️ Kavach Protection Active',
      body:
          'You are now in Protection Mode. Say "help" or "bachao" to trigger SOS.',
      ongoing: true, // stays until protection is turned off
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

  // ── SOS TRIGGERED ───────────────────────────────────────────────

  Future<void> showSOSTriggered() async {
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
    if (!_initialized) await init();

    final androidDetails = AndroidNotificationDetails(
      'kavach_channel', // channel ID
      'Kavach Alerts', // channel name
      channelDescription: 'Kavach SOS protection alerts',
      importance: importance,
      priority: priority,
      ongoing: ongoing, // ongoing = cannot be swiped away
      autoCancel: !ongoing,
      playSound: false, // no sound — app manages its own siren
      icon: '@mipmap/ic_launcher',
    );

    final details = NotificationDetails(android: androidDetails);

    await _plugin.show(id, title, body, details, payload: payload);
    print("[Notification] Shown: $title");
  }

  Future<void> _cancel(int id) async {
    await _plugin.cancel(id);
  }

  Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }
}

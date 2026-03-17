import 'dart:convert';
import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter_background_messenger/flutter_background_messenger.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';

import 'contact_service.dart';

/// SOSService — Sends SMS to all contacts + pings your server.
///
/// Replace _serverUrl with your actual endpoint.

class SOSService {
  // ── 🔧 Replace with your server URL ──────────────────────────
  static const String _serverUrl = 'https://YOUR_SERVER_URL/api/sos';
  // ─────────────────────────────────────────────────────────────

  final _messenger = FlutterBackgroundMessenger();
  bool _isSending = false;

  Future<void> sendSOS(ContactService contactService) async {
    if (_isSending) {
      print("[SOS] ⚠️ Already sending, skipping");
      return;
    }
    _isSending = true;
    print("[SOS] 🚨 sendSOS() called");

    try {
      // ── Get location ────────────────────────────────────────
      final position = await _getLocation();
      final lat = position?.latitude;
      final lng = position?.longitude;
      final mapsLink = (lat != null && lng != null)
          ? 'https://maps.google.com/?q=$lat,$lng'
          : 'Location unavailable';

      print("[SOS] 📍 Location: $lat, $lng");

      // ── Get device name ──────────────────────────────────────
      final deviceName = await _getDeviceName();
      final timestamp = DateTime.now();

      // ── Send SMS + ping server in parallel ──────────────────
      await Future.wait([
        _sendSMS(
          contacts: contactService,
          lat: lat,
          lng: lng,
          mapsLink: mapsLink,
          deviceName: deviceName,
          timestamp: timestamp,
        ),
        _pingServer(
          lat: lat,
          lng: lng,
          deviceName: deviceName,
          timestamp: timestamp,
        ),
      ]);
    } catch (e) {
      print("[SOS] ❌ Error: $e");
    } finally {
      _isSending = false;
    }
  }

  // ── LOCATION ─────────────────────────────────────────────────

  Future<Position?> _getLocation() async {
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        print("[SOS] ❌ Location permission denied");
        return null;
      }
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );
    } catch (e) {
      print("[SOS] ❌ Location error: $e");
      return null;
    }
  }

  // ── DEVICE NAME ──────────────────────────────────────────────

  Future<String> _getDeviceName() async {
    try {
      final info = DeviceInfoPlugin();
      if (Platform.isAndroid) {
        final a = await info.androidInfo;
        return '${a.manufacturer} ${a.model}';
      } else if (Platform.isIOS) {
        final i = await info.iosInfo;
        return i.name;
      }
    } catch (e) {
      print("[SOS] ⚠️ Device info error: $e");
    }
    return 'Unknown Device';
  }

  // ── SMS ───────────────────────────────────────────────────────

  Future<void> _sendSMS({
    required ContactService contacts,
    double? lat,
    double? lng,
    required String mapsLink,
    required String deviceName,
    required DateTime timestamp,
  }) async {
    if (contacts.contacts.isEmpty) {
      print("[SOS] ⚠️ No contacts — SMS skipped");
      return;
    }

    // Check SMS permission
    final smsStatus = await Permission.sms.status;
    if (!smsStatus.isGranted) {
      final result = await Permission.sms.request();
      if (!result.isGranted) {
        print("[SOS] ❌ SMS permission denied");
        return;
      }
    }

    final message = '🚨 KAVACH SOS ALERT 🚨\n'
        'Device: $deviceName\n'
        'Time: ${_fmt(timestamp)}\n'
        'Location: $mapsLink\n'
        '${lat != null ? 'Coordinates: $lat, $lng\n' : ''}'
        'PLEASE RESPOND IMMEDIATELY!';

    print("[SOS] 📱 Sending SMS to ${contacts.contacts.length} contacts...");

    for (final contact in contacts.contacts) {
      try {
        final success = await _messenger.sendSMS(
          phoneNumber: contact.phone,
          message: message,
        );
        print(
            "[SOS] ${success ? '✅' : '❌'} SMS to ${contact.name} (${contact.phone})");
      } catch (e) {
        print("[SOS] ❌ SMS error for ${contact.name}: $e");
      }
    }
  }

  // ── SERVER PING ───────────────────────────────────────────────

  Future<void> _pingServer({
    double? lat,
    double? lng,
    required String deviceName,
    required DateTime timestamp,
  }) async {
    if (_serverUrl.contains('YOUR_SERVER_URL')) {
      print("[SOS] ⚠️ Server URL not configured — skipping ping");
      return;
    }

    try {
      final payload = {
        'event': 'SOS_TRIGGERED',
        'device': deviceName,
        'timestamp': timestamp.toIso8601String(),
        'latitude': lat,
        'longitude': lng,
        'maps_link':
            lat != null ? 'https://maps.google.com/?q=$lat,$lng' : null,
      };

      print("[SOS] 📡 Pinging server: $_serverUrl");

      final response = await http
          .post(
            Uri.parse(_serverUrl),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 10));

      print("[SOS] 📡 Server response: ${response.statusCode}");
    } catch (e) {
      // Non-fatal — SMS already sent even if server unreachable
      print("[SOS] ⚠️ Server ping failed (non-fatal): $e");
    }
  }

  // ── HELPERS ──────────────────────────────────────────────────

  String _fmt(DateTime dt) =>
      '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} '
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:${dt.second.toString().padLeft(2, '0')}';
}

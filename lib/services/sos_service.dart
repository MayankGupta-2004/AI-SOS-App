import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart'; // for MethodChannel native SMS
import 'package:device_info_plus/device_info_plus.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import 'contact_service.dart';
import '../config/app_config.dart';

/// SOSService — Handles SOS event lifecycle.
///
/// ✅ SMS now sent via native Android SmsManager (MethodChannel)
/// ✅ Removed flutter_background_messenger (unreliable on OEM devices)
/// ✅ Live location every 10 seconds
/// ✅ URLs from AppConfig

class SOSResult {
  final bool success;
  final String message;
  final String? sessionId;

  SOSResult({required this.success, required this.message, this.sessionId});
}

class SOSService {
  String get _serverUrl => AppConfig.serverUrl;
  String get _locationUrl => AppConfig.locationUrl;

  // Native SMS channel — bypasses flutter_background_messenger
  static const _smsChannel = MethodChannel('com.example.mobile_app/sms');

  bool _isSending = false;
  Timer? _locationTimer;
  String? _activeSessionId;

  // ── MAIN SOS TRIGGER ─────────────────────────────────────────

  Future<SOSResult> sendSOS(ContactService contactService) async {
    if (_isSending) {
      return SOSResult(success: false, message: 'SOS already in progress');
    }
    _isSending = true;
    debugPrint('[SOS] sendSOS() called');

    try {
      final results = await Future.wait([
        _getLocation(),
        _getDeviceName(),
        _getDeviceIP(),
      ]).timeout(
        const Duration(seconds: 15),
        onTimeout: () => [null, 'Unknown Device', 'IP unavailable'],
      );

      final position = results[0] as Position?;
      final deviceName = results[1] as String;
      final deviceIP = results[2] as String;

      final lat = position?.latitude;
      final lng = position?.longitude;
      final mapsLink = (lat != null && lng != null)
          ? 'https://maps.google.com/?q=$lat,$lng'
          : 'Location unavailable';

      final timestamp = DateTime.now();
      _activeSessionId = 'SOS_${timestamp.millisecondsSinceEpoch}';

      debugPrint('[SOS] Location: $lat, $lng');
      debugPrint('[SOS] Device: $deviceName | IP: $deviceIP');
      debugPrint('[SOS] Session: $_activeSessionId');

      final sendResults = await Future.wait([
        _sendSMS(
          contacts: contactService,
          lat: lat,
          lng: lng,
          mapsLink: mapsLink,
          deviceName: deviceName,
          timestamp: timestamp,
        ).catchError((e) {
          debugPrint('[SOS] ⚠️ SMS error (non-fatal): $e');
          return false;
        }),
        _pingServer(
          lat: lat,
          lng: lng,
          mapsLink: mapsLink,
          deviceName: deviceName,
          deviceIP: deviceIP,
          timestamp: timestamp,
          sessionId: _activeSessionId!,
        ).catchError((e) {
          debugPrint('[SOS] ⚠️ Server error (non-fatal): $e');
          return false;
        }),
      ]);

      // FIX: removed unnecessary `as bool` casts — Future.wait<bool> already
      // types each element correctly when both futures return bool.
      final smsSent = sendResults[0];
      final serverPinged = sendResults[1];

      _startLiveTracking(deviceName, deviceIP);

      return SOSResult(
        success: true,
        message:
            'SOS sent${smsSent ? " + SMS" : ""}${serverPinged ? " + Server" : ""}',
        sessionId: _activeSessionId,
      );
    } catch (e) {
      debugPrint('[SOS] ❌ Error: $e');
      return SOSResult(success: false, message: 'SOS failed: $e');
    } finally {
      _isSending = false;
    }
  }

  // ── LIVE LOCATION TRACKING ────────────────────────────────────

  void _startLiveTracking(String deviceName, String deviceIP) {
    _locationTimer?.cancel();
    debugPrint('[SOS] 📍 Live tracking — every 10 seconds');

    _locationTimer = Timer.periodic(const Duration(seconds: 10), (timer) async {
      if (_activeSessionId == null) {
        timer.cancel();
        return;
      }

      try {
        final position = await _getLocation();
        final lat = position?.latitude;
        final lng = position?.longitude;
        if (lat == null || lng == null) return;

        final mapsLink = 'https://maps.google.com/?q=$lat,$lng';
        debugPrint('[SOS] 📍 Live: $lat, $lng');

        await http
            .post(
              Uri.parse(_locationUrl),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({
                'session_id': _activeSessionId,
                'latitude': lat,
                'longitude': lng,
                'maps_link': mapsLink,
                'device_name': deviceName,
                'device_ip': deviceIP,
                'timestamp': DateTime.now().toIso8601String(),
              }),
            )
            .timeout(const Duration(seconds: 10));
        debugPrint('[SOS] ✅ Live location sent');
      } catch (e) {
        debugPrint('[SOS] ⚠️ Live location error: $e');
      }
    });
  }

  void stopLiveTracking() {
    _locationTimer?.cancel();
    _locationTimer = null;
    _activeSessionId = null;
    debugPrint('[SOS] Live tracking stopped');
  }

  // ── LOCATION ─────────────────────────────────────────────────

  Future<Position?> _getLocation() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return null;

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      // FIX: wrapped single-statement if body in curly braces
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }

      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );
    } catch (e) {
      debugPrint('[SOS] ⚠️ Location error: $e');
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
      debugPrint('[SOS] ⚠️ Device info error: $e');
    }
    return 'Unknown Device';
  }

  // ── DEVICE IP ────────────────────────────────────────────────

  Future<String> _getDeviceIP() async {
    try {
      final interfaces = await NetworkInterface.list(
        includeLoopback: false,
        type: InternetAddressType.IPv4,
      );
      for (final iface in interfaces) {
        for (final addr in iface.addresses) {
          if (!addr.isLoopback) return addr.address;
        }
      }
    } catch (e) {
      debugPrint('[SOS] ⚠️ IP error: $e');
    }
    return 'IP unavailable';
  }

  // ── SMS ───────────────────────────────────────────────────────

  Future<bool> _sendSMS({
    required ContactService contacts,
    double? lat,
    double? lng,
    required String mapsLink,
    required String deviceName,
    required DateTime timestamp,
  }) async {
    if (contacts.contacts.isEmpty) {
      debugPrint('[SOS] ⚠️ No contacts');
      return false;
    }

    final trackingLink =
        '${AppConfig.serverBaseUrl}/track/${_activeSessionId ?? ''}';

    final message = 'KAVACH SOS ALERT!\n'
        'Device: $deviceName\n'
        'Time: ${_fmt(timestamp)}\n'
        'Location: $mapsLink\n'
        '${lat != null ? 'Coords: $lat, $lng\n' : ''}'
        'Live Tracking: $trackingLink\n'
        'PLEASE HELP IMMEDIATELY';

    debugPrint('[SOS] Sending SMS to ${contacts.contacts.length} contacts...');

    bool anySent = false;

    if (Platform.isAndroid) {
      // Use native SmsManager via MethodChannel
      // Replaces flutter_background_messenger which silently fails on OEM devices
      for (final contact in contacts.contacts) {
        try {
          final success = await _smsChannel.invokeMethod<bool>('sendSMS', {
                'phone': contact.phone,
                'message': message,
              }) ??
              false;

          debugPrint(
            '[SOS] ${success ? '✅' : '❌'} SMS to ${contact.name} (${contact.phone})',
          );
          if (success) anySent = true;
        } catch (e) {
          debugPrint('[SOS] ⚠️ SMS error for ${contact.name}: $e');
        }
      }
    } else if (Platform.isIOS) {
      // iOS: URL scheme (known limitation — opens compose screen)
      for (final contact in contacts.contacts) {
        try {
          final smsUri = Uri(
            scheme: 'sms',
            path: contact.phone,
            queryParameters: {'body': message},
          );
          if (await canLaunchUrl(smsUri)) {
            await launchUrl(smsUri);
            anySent = true;
            debugPrint('[SOS] ✅ SMS launched for ${contact.name} (iOS)');
          }
        } catch (e) {
          debugPrint('[SOS] ⚠️ iOS SMS error for ${contact.name}: $e');
        }
      }
    }

    return anySent;
  }

  // ── SERVER PING ───────────────────────────────────────────────

  Future<bool> _pingServer({
    double? lat,
    double? lng,
    required String mapsLink,
    required String deviceName,
    required String deviceIP,
    required DateTime timestamp,
    required String sessionId,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse(_serverUrl),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'event': 'SOS_TRIGGERED',
              'session_id': sessionId,
              'timestamp': timestamp.toIso8601String(),
              'device_name': deviceName,
              'device_ip': deviceIP,
              'latitude': lat,
              'longitude': lng,
              'maps_link': mapsLink,
            }),
          )
          .timeout(const Duration(seconds: 10));

      debugPrint('[SOS] Server response: ${response.statusCode}');
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('[SOS] ⚠️ Server ping failed: $e');
      return false;
    }
  }

  String _fmt(DateTime dt) => '${dt.day.toString().padLeft(2, '0')}/'
      '${dt.month.toString().padLeft(2, '0')}/'
      '${dt.year} '
      '${dt.hour.toString().padLeft(2, '0')}:'
      '${dt.minute.toString().padLeft(2, '0')}:'
      '${dt.second.toString().padLeft(2, '0')}';

  void dispose() {
    stopLiveTracking();
  }
}

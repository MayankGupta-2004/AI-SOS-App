import 'dart:convert';
import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter_background_messenger/flutter_background_messenger.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';

import 'contact_service.dart';

class SOSService {
  // ✅ Replace with your actual server URL
  static const String _serverUrl =
      'https://kavach-server-zmj5.onrender.com/api/sos';

  final _messenger = FlutterBackgroundMessenger();
  bool _isSending = false;

  Future<void> sendSOS(ContactService contactService) async {
    if (_isSending) return;
    _isSending = true;
    print("[SOS] sendSOS() called");

    try {
      // Get all data in parallel for speed
      final results = await Future.wait([
        _getLocation(),
        _getDeviceName(),
        _getDeviceIP(),
      ]);

      final position = results[0] as Position?;
      final deviceName = results[1] as String;
      final deviceIP = results[2] as String;

      final lat = position?.latitude;
      final lng = position?.longitude;
      final mapsLink = (lat != null && lng != null)
          ? 'https://maps.google.com/?q=$lat,$lng'
          : 'Location unavailable';

      final timestamp = DateTime.now();

      print("[SOS] Location: $lat, $lng");
      print("[SOS] Device: $deviceName | IP: $deviceIP");

      // Run SMS + server ping in parallel
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
          mapsLink: mapsLink,
          deviceName: deviceName,
          deviceIP: deviceIP,
          timestamp: timestamp,
        ),
      ]);
    } catch (e) {
      print("[SOS] Error: $e");
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
          permission == LocationPermission.deniedForever) return null;
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );
    } catch (e) {
      print("[SOS] Location error: $e");
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
      print("[SOS] Device info error: $e");
    }
    return 'Unknown Device';
  }

  // ── DEVICE IP ADDRESS ────────────────────────────────────────
  // Gets the device's current WiFi/mobile IP address

  Future<String> _getDeviceIP() async {
    try {
      // Get all network interfaces
      final interfaces = await NetworkInterface.list(
        includeLoopback: false,
        type: InternetAddressType.IPv4,
      );

      for (final interface in interfaces) {
        for (final addr in interface.addresses) {
          // Skip loopback (127.x.x.x)
          if (!addr.isLoopback) {
            print("[SOS] Device IP: ${addr.address} (${interface.name})");
            return addr.address;
          }
        }
      }
    } catch (e) {
      print("[SOS] IP error: $e");
    }
    return 'IP unavailable';
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
      print("[SOS] No contacts saved");
      return;
    }

    final smsStatus = await Permission.sms.status;
    if (!smsStatus.isGranted) {
      final result = await Permission.sms.request();
      if (!result.isGranted) {
        print("[SOS] SMS permission denied");
        return;
      }
    }

    final message = 'KAVACH SOS ALERT!\n'
        'Device: $deviceName\n'
        'Time: ${_fmt(timestamp)}\n'
        'Location: $mapsLink\n'
        '${lat != null ? 'Coords: $lat, $lng\n' : ''}'
        'PLEASE HELP IMMEDIATELY';

    print("[SOS] Sending SMS to ${contacts.contacts.length} contacts...");

    for (final contact in contacts.contacts) {
      try {
        final success = await _messenger.sendSMS(
          phoneNumber: contact.phone,
          message: message,
        );
        print(
            "[SOS] ${success ? '✅' : '❌'} SMS to ${contact.name} (${contact.phone})");
      } catch (e) {
        print("[SOS] SMS error for ${contact.name}: $e");
      }
    }
  }

  // ── SERVER PING ───────────────────────────────────────────────
  // Sends: timestamp, live location, maps link, device name, device IP
  // Does NOT send contact details

  Future<void> _pingServer({
    double? lat,
    double? lng,
    required String mapsLink,
    required String deviceName,
    required String deviceIP,
    required DateTime timestamp,
  }) async {
    if (_serverUrl.contains('YOUR_SERVER_URL')) {
      print("[SOS] Server URL not configured — skipping ping");
      return;
    }

    try {
      final payload = {
        'event': 'SOS_TRIGGERED',
        'timestamp': timestamp.toIso8601String(),
        'device_name': deviceName,
        'device_ip': deviceIP,
        'latitude': lat,
        'longitude': lng,
        'maps_link': mapsLink,
      };

      print("[SOS] Pinging server with payload: $payload");

      final response = await http
          .post(
            Uri.parse(_serverUrl),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 10));

      print("[SOS] Server response: ${response.statusCode}");
    } catch (e) {
      print("[SOS] Server ping failed (non-fatal): $e");
    }
  }

  // ── HELPERS ──────────────────────────────────────────────────

  String _fmt(DateTime dt) => '${dt.day.toString().padLeft(2, '0')}/'
      '${dt.month.toString().padLeft(2, '0')}/'
      '${dt.year} '
      '${dt.hour.toString().padLeft(2, '0')}:'
      '${dt.minute.toString().padLeft(2, '0')}:'
      '${dt.second.toString().padLeft(2, '0')}';
}

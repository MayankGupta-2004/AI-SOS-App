import 'package:permission_handler/permission_handler.dart';

/// PermissionService — requests ALL required permissions at app startup.
///
/// Call requestAllPermissions() before starting any services.
/// Shows which permissions were granted/denied in console.

class PermissionService {
  /// Request every permission the app needs.
  /// Returns true if all critical permissions are granted.
  static Future<bool> requestAllPermissions() async {
    print("[Permissions] Requesting all permissions...");

    // Request all at once — Android shows one dialog per permission group
    final statuses = await [
      Permission.microphone, // speech-to-text + recording
      Permission.location, // GPS for SOS
      Permission.locationWhenInUse, // GPS active
      Permission.sms, // send SOS SMS
      Permission.storage, // save recording to phone
      Permission.phone, // device info
    ].request();

    // Log each result
    statuses.forEach((permission, status) {
      print("[Permissions] ${permission.toString()}: $status");
    });

    // Check critical permissions
    final micGranted = statuses[Permission.microphone]?.isGranted ?? false;
    final locationGranted = statuses[Permission.location]?.isGranted == true ||
        statuses[Permission.locationWhenInUse]?.isGranted == true;
    final smsGranted = statuses[Permission.sms]?.isGranted ?? false;

    print(
        "[Permissions] Mic: $micGranted | Location: $locationGranted | SMS: $smsGranted");

    if (!micGranted) {
      print(
          "[Permissions] ❌ MICROPHONE denied — speech & recording will not work");
    }
    if (!locationGranted) {
      print("[Permissions] ❌ LOCATION denied — GPS unavailable");
    }
    if (!smsGranted) {
      print("[Permissions] ❌ SMS denied — contacts will not receive alert");
    }

    // Return true if mic + location granted (minimum for app to work)
    return micGranted && locationGranted;
  }

  /// Check if microphone is currently granted
  static Future<bool> hasMicPermission() async {
    return await Permission.microphone.isGranted;
  }

  /// Check if SMS is currently granted
  static Future<bool> hasSmsPermission() async {
    return await Permission.sms.isGranted;
  }

  /// Open app settings if user permanently denied a permission
  static Future<void> openSettings() async {
    await openAppSettings();
  }
}

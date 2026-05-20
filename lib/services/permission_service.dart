import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

/// PermissionService — Cross-platform permission handling (Android + iOS)
///
/// Call requestAllPermissions() before starting any services.
/// Handles platform-specific permission differences.

class PermissionService {
  /// Request every permission the app needs.
  /// Returns true if all critical permissions are granted.
  static Future<bool> requestAllPermissions() async {
    debugPrint(
        '[Permissions] Requesting all permissions (${Platform.operatingSystem})...');

    final List<Permission> permissions = [
      Permission.microphone, // speech-to-text + recording
      Permission.location, // GPS for SOS
      Permission.locationWhenInUse, // GPS active
      Permission.notification, // push notifications
    ];

    // Platform-specific permissions
    if (Platform.isAndroid) {
      permissions.addAll([
        Permission.sms, // send SOS SMS (Android only)
        Permission.storage, // save recording to phone
        Permission.phone, // device info
      ]);
    }

    // iOS: speech recognition requires separate permission
    if (Platform.isIOS) {
      permissions.add(Permission.speech);
    }

    // Request all at once
    final Map<Permission, PermissionStatus> statuses;
    try {
      statuses = await permissions.request();
    } catch (e) {
      debugPrint('[Permissions] ❌ Request failed: $e');
      return false;
    }

    // Log each result
    statuses.forEach((permission, status) {
      final icon = status.isGranted ? '✅' : '❌';
      debugPrint('[Permissions] $icon ${permission.toString()}: $status');
    });

    // Check critical permissions
    final micGranted = statuses[Permission.microphone]?.isGranted ?? false;
    final locationGranted = statuses[Permission.location]?.isGranted == true ||
        statuses[Permission.locationWhenInUse]?.isGranted == true;

    bool smsGranted = true;
    if (Platform.isAndroid) {
      smsGranted = statuses[Permission.sms]?.isGranted ?? false;
    }

    debugPrint(
      '[Permissions] Summary — Mic: $micGranted | Location: $locationGranted | SMS: $smsGranted',
    );

    if (!micGranted) {
      debugPrint(
          '[Permissions] ⚠️ MICROPHONE denied — speech & recording will not work');
    }
    if (!locationGranted) {
      debugPrint('[Permissions] ⚠️ LOCATION denied — GPS unavailable');
    }
    if (!smsGranted && Platform.isAndroid) {
      debugPrint(
          '[Permissions] ⚠️ SMS denied — contacts will not receive alert');
    }

    // Return true if mic + location granted (minimum for app to work)
    return micGranted && locationGranted;
  }

  /// Check if microphone is currently granted
  static Future<bool> hasMicPermission() async {
    try {
      return await Permission.microphone.isGranted;
    } catch (e) {
      debugPrint('[Permissions] ❌ Mic check error: $e');
      return false;
    }
  }

  /// Check if SMS is currently granted (Android only)
  static Future<bool> hasSmsPermission() async {
    if (!Platform.isAndroid) return false;
    try {
      return await Permission.sms.isGranted;
    } catch (e) {
      debugPrint('[Permissions] ❌ SMS check error: $e');
      return false;
    }
  }

  /// Check if speech recognition is available (iOS)
  static Future<bool> hasSpeechPermission() async {
    // Android doesn't need a separate speech permission
    if (!Platform.isIOS) return true;
    try {
      return await Permission.speech.isGranted;
    } catch (e) {
      debugPrint('[Permissions] ❌ Speech check error: $e');
      return false;
    }
  }

  /// Open app settings if user permanently denied a permission
  static Future<void> openSettings() async {
    try {
      await openAppSettings();
    } catch (e) {
      debugPrint('[Permissions] ❌ Open settings error: $e');
    }
  }
}

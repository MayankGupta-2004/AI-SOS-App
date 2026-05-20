import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/ai_service.dart';
import '../services/contact_service.dart';
import '../services/notification_service.dart';
import '../services/recording_service.dart';
import '../services/siren_service.dart';
import '../services/sos_service.dart';
import '../services/language_service.dart';

// Add this provider:

// ✅ FIXED: removed unused import of kavach_listener.dart

// ═══════════════════════════════════════════════════════════════════
// KAVACH STATE — Riverpod State Management
// ═══════════════════════════════════════════════════════════════════

class KavachState {
  final bool isProtectionActive;
  final bool isSosActive;
  final bool isRecording;
  final bool isCountdownActive;
  final int countdownSeconds;
  final bool isSpeechListening;
  final String statusHindi;
  final String statusEnglish;
  final String? errorMessage;
  final bool isLoading;

  const KavachState({
    this.isProtectionActive = false,
    this.isSosActive = false,
    this.isRecording = false,
    this.isCountdownActive = false,
    this.countdownSeconds = 3,
    this.isSpeechListening = false,
    this.statusHindi = 'आप सुरक्षित हैं',
    this.statusEnglish = 'Protection is off • Tap to activate',
    this.errorMessage,
    this.isLoading = false,
  });

  // ✅ FIXED: errorMessage can now be properly cleared by passing null
  // Uses a sentinel object to distinguish "pass null" from "not passed"
  KavachState copyWith({
    bool? isProtectionActive,
    bool? isSosActive,
    bool? isRecording,
    bool? isCountdownActive,
    int? countdownSeconds,
    bool? isSpeechListening,
    String? statusHindi,
    String? statusEnglish,
    Object? errorMessage = _sentinel,
    bool? isLoading,
  }) {
    return KavachState(
      isProtectionActive: isProtectionActive ?? this.isProtectionActive,
      isSosActive: isSosActive ?? this.isSosActive,
      isRecording: isRecording ?? this.isRecording,
      isCountdownActive: isCountdownActive ?? this.isCountdownActive,
      countdownSeconds: countdownSeconds ?? this.countdownSeconds,
      isSpeechListening: isSpeechListening ?? this.isSpeechListening,
      statusHindi: statusHindi ?? this.statusHindi,
      statusEnglish: statusEnglish ?? this.statusEnglish,
      // If sentinel → keep old value. If null passed → clear. If string → use it.
      errorMessage: errorMessage == _sentinel
          ? this.errorMessage
          : errorMessage as String?,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

// Sentinel so copyWith can tell "null was explicitly passed" vs "not passed"
const Object _sentinel = Object();

/// Main state notifier
class KavachNotifier extends StateNotifier<KavachState> {
  KavachNotifier() : super(const KavachState());

  void setProtection(bool active) {
    state = state.copyWith(
      isProtectionActive: active,
      statusHindi: active ? 'सुरक्षा चालू है' : 'आप सुरक्षित हैं',
      statusEnglish: active
          ? 'Listening for distress keywords'
          : 'Protection is off • Tap to activate',
    );
  }

  void setSosActive(bool active) {
    state = state.copyWith(
      isSosActive: active,
      statusHindi: active ? '🚨 मदद! एस.ओ.एस.!' : state.statusHindi,
      statusEnglish:
          active ? 'SOS Triggered! Sending alerts...' : state.statusEnglish,
    );
  }

  void setRecording(bool recording) {
    state = state.copyWith(isRecording: recording);
  }

  void startCountdown() {
    state = state.copyWith(isCountdownActive: true, countdownSeconds: 3);
  }

  void updateCountdown(int seconds) {
    state = state.copyWith(countdownSeconds: seconds);
  }

  void cancelCountdown() {
    state = state.copyWith(isCountdownActive: false, countdownSeconds: 3);
  }

  void setSpeechListening(bool listening) {
    state = state.copyWith(isSpeechListening: listening);
  }

  void setStatus(String hindi, String english) {
    state = state.copyWith(statusHindi: hindi, statusEnglish: english);
  }

  // ✅ FIXED: can now actually clear error by passing null
  void setError(String? error) {
    state = state.copyWith(errorMessage: error);
  }

  void setLoading(bool loading) {
    state = state.copyWith(isLoading: loading);
  }

  void resetAfterSosStop(bool stillProtected) {
    state = state.copyWith(
      isSosActive: false,
      statusHindi: stillProtected ? 'सुरक्षा चालू है' : 'आप सुरक्षित हैं',
      statusEnglish:
          stillProtected ? 'Listening for keywords...' : 'Protection is off',
    );
  }

  void resetAll() {
    state = const KavachState();
  }
}

// ═══════════════════════════════════════════════════════════════════
// PROVIDERS
// ═══════════════════════════════════════════════════════════════════

final kavachProvider =
    StateNotifierProvider<KavachNotifier, KavachState>((ref) {
  return KavachNotifier();
});

final aiServiceProvider = Provider<AIService>((ref) => AIService());
final contactServiceProvider =
    Provider<ContactService>((ref) => ContactService());
final sosServiceProvider = Provider<SOSService>((ref) => SOSService());
final sirenServiceProvider = Provider<SirenService>((ref) => SirenService());
final recordingServiceProvider =
    Provider<RecordingService>((ref) => RecordingService());
final notificationServiceProvider =
    Provider<NotificationService>((ref) => NotificationService());
final languageServiceProvider =
    Provider<LanguageService>((ref) => LanguageService());

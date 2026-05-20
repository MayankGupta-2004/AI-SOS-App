// AppConfig — All secret keys and server URLs live here.
//
// ⚠️ THIS FILE IS IN .gitignore — NEVER COMMIT IT
// Share app_config.example.dart instead (has no real values)

class AppConfig {
  // ── Server URLs ───────────────────────────────────────────────
  static const String serverBaseUrl = 'https://kavach-server-zmj5.onrender.com';

  static const String serverUrl =
      'https://kavach-server-zmj5.onrender.com/api/sos';

  static const String locationUrl =
      'https://kavach-server-zmj5.onrender.com/api/location';

  // ── AI API Key (add your Gemini key here) ────────────────────
  // Get your free key at: https://aistudio.google.com/app/apikey
  static const String geminiApiKey = 'YOUR_GEMINI_API_KEY_HERE';
}

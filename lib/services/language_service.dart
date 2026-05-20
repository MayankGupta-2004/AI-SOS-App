import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// LanguageService — manages user's 2 selected languages
/// and provides distress keywords for those languages only.
///
/// ARCHITECTURE:
///   User selects 2 languages on first launch
///   Only those keywords are loaded into the detector
///   This makes detection faster and more accurate
///   (fewer false positives from unrelated languages)

class LanguageService {
  static const String _prefsKey = 'selected_languages';
  static const int maxSelections = 2;

  // Singleton
  static final LanguageService _instance = LanguageService._internal();
  factory LanguageService() => _instance;
  LanguageService._internal();

  List<String> _selectedCodes = [];

  List<String> get selectedCodes => List.unmodifiable(_selectedCodes);

  bool get hasSelection => _selectedCodes.length == maxSelections;

  // ── ALL SUPPORTED LANGUAGES ───────────────────────────────────

  static const List<KavachLanguage> allLanguages = [
    KavachLanguage(
      code: 'hi',
      name: 'Hindi',
      nativeName: 'हिंदी',
      sttLocale: 'hi-IN',
      flag: '🇮🇳',
      keywords: [
        'bachao',
        'koi bachao',
        'bacchao',
        'mujhe bachao',
        'bachao mujhe',
        'madad',
        'madad karo',
        'madad chahiye',
        'madad karo please',
        'khatra',
        'police bulao',
        'बचाओ',
        'कोई बचाओ',
        'मुझे बचाओ',
        'मदद',
        'मदद करो',
        'मुझे मदद चाहिए',
        'सहायता',
        'खतरा',
        'इमरजेंसी',
        'हेल्प',
        'मुझे छोड़ो',
        'छोड़ो मुझे',
        'नहीं नहीं',
        'बचाओ मुझे',
      ],
    ),
    KavachLanguage(
      code: 'en',
      name: 'English',
      nativeName: 'English',
      sttLocale: 'en-IN',
      flag: '🇬🇧',
      keywords: [
        'help',
        'help me',
        'save me',
        'somebody help',
        'please help',
        'help help',
        'emergency',
        'danger',
        'sos',
        'call police',
        'let me go',
        'leave me',
        'stop it',
        'no no no',
        'i need help',
        'someone help me',
      ],
    ),
    KavachLanguage(
      code: 'ta',
      name: 'Tamil',
      nativeName: 'தமிழ்',
      sttLocale: 'ta-IN',
      flag: '🏳️',
      keywords: [
        'udavi',
        'udavungal',
        'kaaparu',
        'aapathu',
        'உதவி',
        'உதவுங்கள்',
        'காப்பாற்று',
        'ஆபத்து',
        'யாராவது உதவுங்கள்',
        'என்னை விடுங்கள்',
      ],
    ),
    KavachLanguage(
      code: 'te',
      name: 'Telugu',
      nativeName: 'తెలుగు',
      sttLocale: 'te-IN',
      flag: '🏳️',
      keywords: [
        'sahayam',
        'pramaadam',
        'rakshimchu',
        'సహాయం',
        'సహాయం చేయండి',
        'ప్రమాదం',
        'రక్షించు',
        'నన్ను వదలండి',
        'ఎవరైనా సహాయం చేయండి',
      ],
    ),
    KavachLanguage(
      code: 'bn',
      name: 'Bengali',
      nativeName: 'বাংলা',
      sttLocale: 'bn-IN',
      flag: '🏳️',
      keywords: [
        'shahajjo',
        'bachao',
        'bipod',
        'সাহায্য',
        'সাহায্য করুন',
        'বাঁচাও',
        'বিপদ',
        'আমাকে ছাড়ুন',
        'কেউ সাহায্য করুন',
      ],
    ),
    KavachLanguage(
      code: 'mr',
      name: 'Marathi',
      nativeName: 'मराठी',
      sttLocale: 'mr-IN',
      flag: '🏳️',
      keywords: [
        'madat',
        'madat kara',
        'vachava',
        'dhoka',
        'मदत',
        'मदत करा',
        'वाचवा',
        'धोका',
        'मला सोडा',
        'कोणीतरी मदत करा',
      ],
    ),
    KavachLanguage(
      code: 'gu',
      name: 'Gujarati',
      nativeName: 'ગુજરાતી',
      sttLocale: 'gu-IN',
      flag: '🏳️',
      keywords: [
        'madad',
        'madad karo',
        'bachavo',
        'bhay',
        'મદદ',
        'મદદ કરો',
        'બચાવો',
        'ભય',
        'મને છોડો',
        'કોઈ મદદ કરો',
      ],
    ),
    KavachLanguage(
      code: 'kn',
      name: 'Kannada',
      nativeName: 'ಕನ್ನಡ',
      sttLocale: 'kn-IN',
      flag: '🏳️',
      keywords: [
        'sahaya',
        'sahaya madi',
        'ulisi',
        'apaya',
        'ಸಹಾಯ',
        'ಸಹಾಯ ಮಾಡಿ',
        'ಉಳಿಸಿ',
        'ಅಪಾಯ',
        'ನನ್ನನ್ನು ಬಿಡಿ',
        'ಯಾರಾದರೂ ಸಹಾಯ ಮಾಡಿ',
      ],
    ),
    KavachLanguage(
      code: 'ml',
      name: 'Malayalam',
      nativeName: 'മലയാളം',
      sttLocale: 'ml-IN',
      flag: '🏳️',
      keywords: [
        'sahaayam',
        'sahaayikkoo',
        'rakshikkoo',
        'apakadam',
        'സഹായം',
        'സഹായിക്കൂ',
        'രക്ഷിക്കൂ',
        'അപകടം',
        'എന്നെ വിടൂ',
        'ആരെങ്കിലും സഹായിക്കൂ',
      ],
    ),
    KavachLanguage(
      code: 'pa',
      name: 'Punjabi',
      nativeName: 'ਪੰਜਾਬੀ',
      sttLocale: 'pa-IN',
      flag: '🏳️',
      keywords: [
        'madad',
        'madad karo',
        'bachao',
        'khatra',
        'ਮਦਦ',
        'ਮਦਦ ਕਰੋ',
        'ਬਚਾਓ',
        'ਖਤਰਾ',
        'ਮੈਨੂੰ ਛੱਡੋ',
        'ਕੋਈ ਮਦਦ ਕਰੋ',
      ],
    ),
    KavachLanguage(
      code: 'ur',
      name: 'Urdu',
      nativeName: 'اردو',
      sttLocale: 'ur-IN',
      flag: '🏳️',
      keywords: [
        'madad',
        'madad karo',
        'bachao',
        'مدد',
        'مدد کرو',
        'بچاؤ',
        'خطرہ',
        'مجھے چھوڑو',
        'کوئی مدد کرو',
      ],
    ),
    KavachLanguage(
      code: 'or',
      name: 'Odia',
      nativeName: 'ଓଡ଼ିଆ',
      sttLocale: 'or-IN',
      flag: '🏳️',
      keywords: [
        'sahayya',
        'bachao',
        'bipada',
        'ସାହାଯ୍ୟ',
        'ସାହାଯ୍ୟ କର',
        'ବଞ୍ଚାଅ',
        'ବିପଦ',
      ],
    ),
  ];

  // ── LOAD / SAVE ───────────────────────────────────────────────

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getStringList(_prefsKey);
      if (saved != null && saved.length == maxSelections) {
        _selectedCodes = saved;
        debugPrint('[Language] Loaded: $_selectedCodes');
      } else {
        // Default: Hindi + English
        _selectedCodes = ['hi', 'en'];
        debugPrint('[Language] Using defaults: $_selectedCodes');
      }
    } catch (e) {
      debugPrint('[Language] Load error: $e');
      _selectedCodes = ['hi', 'en'];
    }
  }

  Future<void> save(List<String> codes) async {
    if (codes.length != maxSelections) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_prefsKey, codes);
      _selectedCodes = codes;
      debugPrint('[Language] Saved: $_selectedCodes');
    } catch (e) {
      debugPrint('[Language] Save error: $e');
    }
  }

  Future<void> clearSelection() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefsKey);
      _selectedCodes = [];
    } catch (e) {
      debugPrint('[Language] Clear error: $e');
    }
  }

  // ── KEYWORD ACCESS ────────────────────────────────────────────

  /// Returns combined keywords for the 2 selected languages
  List<String> get activeKeywords {
    final keywords = <String>[];
    for (final code in _selectedCodes) {
      final lang = allLanguages.firstWhere(
        (l) => l.code == code,
        orElse: () => allLanguages.first,
      );
      keywords.addAll(lang.keywords);
    }
    return keywords;
  }

  /// Returns STT locales for selected languages
  List<String> get activeLocales {
    return _selectedCodes.map((code) {
      final lang = allLanguages.firstWhere(
        (l) => l.code == code,
        orElse: () => allLanguages.first,
      );
      return lang.sttLocale;
    }).toList();
  }

  /// Get language object by code
  KavachLanguage? getLanguage(String code) {
    try {
      return allLanguages.firstWhere((l) => l.code == code);
    } catch (_) {
      return null;
    }
  }

  /// Get selected language objects
  List<KavachLanguage> get selectedLanguages {
    return _selectedCodes
        .map((code) => getLanguage(code))
        .whereType<KavachLanguage>()
        .toList();
  }

  /// Check if a text contains any active keyword
  bool containsDistressKeyword(String text) {
    final lower = text.toLowerCase().trim();
    return activeKeywords.any((kw) => lower.contains(kw.toLowerCase()));
  }
}

// ── DATA MODEL ────────────────────────────────────────────────────

class KavachLanguage {
  final String code;
  final String name;
  final String nativeName;
  final String sttLocale;
  final String flag;
  final List<String> keywords;

  const KavachLanguage({
    required this.code,
    required this.name,
    required this.nativeName,
    required this.sttLocale,
    required this.flag,
    required this.keywords,
  });
}

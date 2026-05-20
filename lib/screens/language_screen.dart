import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// LanguageScreen — First-run language selection
///
/// FIX 3 — Three bugs corrected:
///
/// 1. Was storing String? _selected (one language).
///    LanguageService.load() reads 'kavach_languages' as a JSON list of 2.
///    Now stores List<String> _selected and enforces exactly 2 choices.
///
/// 2. Was saving to prefs key 'kavach_language' (singular string).
///    LanguageService reads 'kavach_languages' (list). Key mismatch meant
///    language selection was NEVER loaded by the service.
///    Now saves as jsonEncode(['hi', 'en']) under 'kavach_languages'.
///
/// 3. onLanguageSelected callback was Function(String).
///    main.dart Fix #1 changed it to Function(List<String>).
///    Callback now passes both selected codes.

class LanguageScreen extends StatefulWidget {
  // FIX: callback now receives List<String> (2 codes) not a single String
  final void Function(List<String> codes) onLanguageSelected;

  const LanguageScreen({super.key, required this.onLanguageSelected});

  @override
  State<LanguageScreen> createState() => _LanguageScreenState();
}

class _LanguageScreenState extends State<LanguageScreen>
    with TickerProviderStateMixin {
  // FIX: List, not single String — LanguageService expects exactly 2 codes
  final List<String> _selected = [];
  static const int _requiredSelections = 2;

  // FIX: correct prefs key — must match LanguageService.load()
  static const String _prefsKey = 'kavach_languages';

  late AnimationController _entryCtrl;
  late AnimationController _shimmerCtrl;
  late Animation<double> _entryAnim;
  late Animation<double> _shimmerAnim;

  // All supported languages — code must match LanguageService language codes
  static const List<_Language> _languages = [
    _Language(
        code: 'hi',
        nameLocal: 'हिंदी',
        nameEn: 'Hindi',
        flag: '🇮🇳',
        script: 'बचाओ • मदद'),
    _Language(
        code: 'en',
        nameLocal: 'English',
        nameEn: 'English',
        flag: '🇬🇧',
        script: 'Help • Save me'),
    _Language(
        code: 'ta',
        nameLocal: 'தமிழ்',
        nameEn: 'Tamil',
        flag: '🇮🇳',
        script: 'உதவி • காப்பாற்று'),
    _Language(
        code: 'te',
        nameLocal: 'తెలుగు',
        nameEn: 'Telugu',
        flag: '🇮🇳',
        script: 'సహాయం • రక్షించు'),
    _Language(
        code: 'bn',
        nameLocal: 'বাংলা',
        nameEn: 'Bengali',
        flag: '🇮🇳',
        script: 'সাহায্য • বাঁচাও'),
    _Language(
        code: 'mr',
        nameLocal: 'मराठी',
        nameEn: 'Marathi',
        flag: '🇮🇳',
        script: 'मदत • वाचवा'),
    _Language(
        code: 'gu',
        nameLocal: 'ગુજરાતી',
        nameEn: 'Gujarati',
        flag: '🇮🇳',
        script: 'મદદ • બચાવો'),
    _Language(
        code: 'kn',
        nameLocal: 'ಕನ್ನಡ',
        nameEn: 'Kannada',
        flag: '🇮🇳',
        script: 'ಸಹಾಯ • ಉಳಿಸಿ'),
    _Language(
        code: 'ml',
        nameLocal: 'മലയാളം',
        nameEn: 'Malayalam',
        flag: '🇮🇳',
        script: 'സഹായം • രക്ഷിക്കൂ'),
    _Language(
        code: 'pa',
        nameLocal: 'ਪੰਜਾਬੀ',
        nameEn: 'Punjabi',
        flag: '🇮🇳',
        script: 'ਮਦਦ • ਬਚਾਓ'),
  ];

  // Design tokens — dark premium palette to match HomeScreen
  static const Color _bg = Color(0xFF0A0C12);
  static const Color _card = Color(0xFF12151E);
  static const Color _border = Color(0xFF22263A);
  static const Color _saffron = Color(0xFFFF6B35);
  static const Color _emerald = Color(0xFF00C07F);
  static const Color _textHigh = Color(0xFFF0F4FF);
  static const Color _textMid = Color(0xFF8A90A8);

  @override
  void initState() {
    super.initState();

    _entryCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _entryAnim =
        CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOutQuint);
    _entryCtrl.forward();

    _shimmerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
    _shimmerAnim = Tween<double>(begin: -1.0, end: 2.0).animate(
      CurvedAnimation(parent: _shimmerCtrl, curve: Curves.easeInOut),
    );

    // Pre-select Hindi + English as sensible defaults
    _selected.addAll(['hi', 'en']);
  }

  @override
  void dispose() {
    _entryCtrl.dispose();
    _shimmerCtrl.dispose();
    super.dispose();
  }

  void _toggleLanguage(String code) {
    HapticFeedback.selectionClick();
    setState(() {
      if (_selected.contains(code)) {
        // Don't allow deselecting if only 1 left
        if (_selected.length > 1) _selected.remove(code);
      } else {
        if (_selected.length < _requiredSelections) {
          _selected.add(code);
        } else {
          // Already at limit — replace the second selection
          _selected[1] = code;
        }
      }
    });
  }

  Future<void> _confirm() async {
    if (_selected.length < _requiredSelections) return;
    HapticFeedback.mediumImpact();

    // FIX: save under 'kavach_languages' (correct key) as a comma-joined
    // string that matches how LanguageService.load() reads it.
    // LanguageService expects: prefs.getStringList('kavach_languages')
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_prefsKey, List.from(_selected));
      await prefs.setBool('kavach_onboarded', true);
      debugPrint(
          '[LanguageScreen] Saved languages: $_selected under key: $_prefsKey');
    } catch (e) {
      debugPrint('[LanguageScreen] Save failed: $e');
    }

    if (!mounted) return;
    // FIX: pass full list, not single code
    widget.onLanguageSelected(List.from(_selected));
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ));

    return Scaffold(
      backgroundColor: _bg,
      body: AnimatedBuilder(
        animation: _entryAnim,
        builder: (_, child) => Opacity(
          opacity: _entryAnim.value,
          child: Transform.translate(
            offset: Offset(0, 40 * (1 - _entryAnim.value)),
            child: child,
          ),
        ),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 8),
              _buildSelectionHint(),
              const SizedBox(height: 16),
              _buildSelectedBadges(),
              const SizedBox(height: 16),
              Expanded(child: _buildLanguageGrid()),
              _buildConfirmButton(),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Shield icon + app name
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: _saffron.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _saffron.withValues(alpha: 0.4),
                    width: 1,
                  ),
                ),
                child: const Icon(
                  Icons.shield_rounded,
                  color: _saffron,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'KAVACH',
                style: TextStyle(
                  color: _textHigh,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 5,
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          // Heading
          AnimatedBuilder(
            animation: _shimmerAnim,
            builder: (_, child) {
              return ShaderMask(
                shaderCallback: (bounds) => LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: const [
                    _textHigh,
                    Color(0xFFFFBE0B),
                    _textHigh,
                  ],
                  stops: [
                    (_shimmerAnim.value - 0.3).clamp(0.0, 1.0),
                    _shimmerAnim.value.clamp(0.0, 1.0),
                    (_shimmerAnim.value + 0.3).clamp(0.0, 1.0),
                  ],
                ).createShader(bounds),
                child: child!,
              );
            },
            child: const Text(
              'भाषा चुनें',
              style: TextStyle(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.w900,
                height: 1.1,
              ),
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Choose your 2 languages',
            style: TextStyle(
              color: _textMid,
              fontSize: 14,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  // ── Selection hint bar ─────────────────────────────────────────

  Widget _buildSelectionHint() {
    final remaining = _requiredSelections - _selected.length;
    final done = remaining == 0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: done
              ? _emerald.withValues(alpha: 0.08)
              : _saffron.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: done
                ? _emerald.withValues(alpha: 0.3)
                : _saffron.withValues(alpha: 0.25),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              done
                  ? Icons.check_circle_rounded
                  : Icons.radio_button_unchecked_rounded,
              color: done ? _emerald : _saffron,
              size: 16,
            ),
            const SizedBox(width: 10),
            Text(
              done
                  ? 'Perfect! Both languages selected'
                  : 'Select $remaining more language${remaining > 1 ? "s" : ""}',
              style: TextStyle(
                color: done ? _emerald : _saffron,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            // Progress dots
            Row(
              children: List.generate(_requiredSelections, (i) {
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: i < _selected.length ? 20 : 6,
                  height: 6,
                  margin: const EdgeInsets.only(left: 4),
                  decoration: BoxDecoration(
                    color: i < _selected.length
                        ? (done ? _emerald : _saffron)
                        : _border,
                    borderRadius: BorderRadius.circular(3),
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }

  // ── Selected language badges ───────────────────────────────────

  Widget _buildSelectedBadges() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          // Always show 2 badge slots
          ...List.generate(_requiredSelections, (i) {
            final hasSelection = i < _selected.length;
            final lang = hasSelection
                ? _languages.firstWhere((l) => l.code == _selected[i],
                    orElse: () => _languages.first)
                : null;

            return Padding(
              padding: const EdgeInsets.only(right: 10),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutBack,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color:
                      hasSelection ? _saffron.withValues(alpha: 0.12) : _card,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: hasSelection
                        ? _saffron.withValues(alpha: 0.5)
                        : _border,
                    width: 1.5,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      hasSelection ? lang!.flag : '•',
                      style: const TextStyle(fontSize: 16),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      hasSelection ? lang!.nameEn : 'Language ${i + 1}',
                      style: TextStyle(
                        color: hasSelection ? _saffron : _textMid,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (hasSelection) ...[
                      const SizedBox(width: 6),
                      GestureDetector(
                        onTap: () => _toggleLanguage(_selected[i]),
                        child: Icon(
                          Icons.close_rounded,
                          size: 14,
                          color: _saffron.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  // ── Language grid ──────────────────────────────────────────────

  Widget _buildLanguageGrid() {
    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.55,
      ),
      itemCount: _languages.length,
      itemBuilder: (_, i) {
        final lang = _languages[i];
        final isSelected = _selected.contains(lang.code);
        final selIndex = _selected.indexOf(lang.code); // 0, 1, or -1

        return TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.0, end: 1.0),
          duration: Duration(milliseconds: 250 + i * 45),
          curve: Curves.easeOutCubic,
          builder: (_, v, child) => Opacity(
            opacity: v,
            child: Transform.translate(
              offset: Offset(0, 18 * (1 - v)),
              child: child,
            ),
          ),
          child: GestureDetector(
            onTap: () => _toggleLanguage(lang.code),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOutCubic,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isSelected ? _saffron.withValues(alpha: 0.1) : _card,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color:
                      isSelected ? _saffron.withValues(alpha: 0.55) : _border,
                  width: isSelected ? 1.5 : 1,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: _saffron.withValues(alpha: 0.15),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ]
                    : [],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Text(lang.flag, style: const TextStyle(fontSize: 20)),
                      const Spacer(),
                      // Selection order badge (1 or 2)
                      AnimatedScale(
                        scale: isSelected ? 1.0 : 0.0,
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeOutBack,
                        child: Container(
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            color: _saffron,
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              '${selIndex + 1}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        lang.nameLocal,
                        style: TextStyle(
                          color: isSelected ? _saffron : _textHigh,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          height: 1.2,
                        ),
                      ),
                      Text(
                        lang.script,
                        style: TextStyle(
                          color: _textMid,
                          fontSize: 9.5,
                          height: 1.4,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ── Confirm button ─────────────────────────────────────────────

  Widget _buildConfirmButton() {
    final ready = _selected.length == _requiredSelections;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: double.infinity,
        height: 58,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: ready
                ? [const Color(0xFFFF8A50), _saffron, const Color(0xFFCC3D00)]
                : [
                    const Color(0xFF1E2130),
                    const Color(0xFF1E2130),
                  ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(18),
          boxShadow: ready
              ? [
                  BoxShadow(
                    color: _saffron.withValues(alpha: 0.4),
                    blurRadius: 20,
                    offset: const Offset(0, 6),
                  ),
                ]
              : [],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: ready ? _confirm : null,
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    ready
                        ? Icons.arrow_forward_rounded
                        : Icons.touch_app_rounded,
                    color: ready ? Colors.white : _textMid,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    ready ? 'आगे बढ़ें  •  Continue' : 'Select 2 languages',
                    style: TextStyle(
                      color: ready ? Colors.white : _textMid,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Data class ─────────────────────────────────────────────────

class _Language {
  final String code;
  final String nameLocal;
  final String nameEn;
  final String flag;
  final String script; // example distress phrase in that language

  const _Language({
    required this.code,
    required this.nameLocal,
    required this.nameEn,
    required this.flag,
    required this.script,
  });
}

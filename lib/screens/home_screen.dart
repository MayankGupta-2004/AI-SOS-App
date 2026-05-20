import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/ai_service.dart';
import '../services/contact_service.dart';
import '../services/kavach_listener.dart';
import '../services/recording_service.dart';
import '../services/siren_service.dart';
import '../services/sos_service.dart';
import '../widgets/countdown_dialog.dart';
import 'contacts_screen.dart';

class HomeScreen extends StatefulWidget {
  final AIService aiService;
  final ContactService contactService;

  const HomeScreen({
    super.key,
    required this.aiService,
    required this.contactService,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  // ── Services ─────────────────────────────────────────────────────
  late final SOSService _sos;
  late final SirenService _siren;
  late final RecordingService _rec;
  late final KavachListener _kavach;

  // ── State ─────────────────────────────────────────────────────────
  bool _protected = false;
  bool _sosActive = false;
  bool _recording = false;
  bool _countdownVisible = false;
  String _statusH = 'आप सुरक्षित हैं';
  String _statusE = 'Protection is off • Tap to activate';

  // ── NEW Palette — Dark Glassmorphism ──────────────────────────────
  // Background
  static const Color _bg        = Color(0xFF0A0C12);
  static const Color _bgCard    = Color(0xFF12151E);
  static const Color _surface   = Color(0xFF1A1D28);

  // Accents
  static const Color _crimson   = Color(0xFFE63946); // SOS red
  static const Color _ember     = Color(0xFFFF6B35); // manual trigger
  static const Color _emerald   = Color(0xFF00C07F); // protected
  static const Color _teal      = Color(0xFF00E5C3); // teal highlight
  static const Color _gold      = Color(0xFFFFBE0B); // badges / GPS

  // Text
  static const Color _textHigh  = Color(0xFFF0F4FF);
  static const Color _textMid   = Color(0xFF8A90A8);
  static const Color _textLow   = Color(0xFF3E4258);

  // Borders
  static const Color _border    = Color(0xFF22263A);

  // ── Animations ────────────────────────────────────────────────────
  late AnimationController _orbCtrl;
  late AnimationController _pulseCtrl;
  late AnimationController _waveCtrl;
  late AnimationController _entryCtrl;
  late AnimationController _idleCtrl;
  late AnimationController _scanCtrl;

  late Animation<double> _orbAnim;
  late Animation<double> _pulseAnim;
  late Animation<double> _waveAnim;
  late Animation<double> _entryAnim;
  late Animation<double> _idleAnim;
  late Animation<double> _scanAnim;

  @override
  void initState() {
    super.initState();
    _sos   = SOSService();
    _siren = SirenService();
    _rec   = RecordingService();

    _kavach = KavachListener(
      sosService: _sos,
      sirenService: _siren,
      recordingService: _rec,
      contactService: widget.contactService,
      onStatusUpdate: (s) {
        if (!mounted) return;
        setState(() {
          if (s.contains('Listening') || s.contains('keyword') || s.contains('सुन')) {
            _statusH = 'सुन रहा हूँ...';
            _statusE = 'Listening for distress keywords';
          } else if (s.contains('Recording') || s.contains('रिकॉर्ड')) {
            _recording = true;
            _statusH = 'रिकॉर्ड हो रहा है';
            _statusE = 'Recording audio evidence (10 min)';
          } else if (s.contains('SMS') || s.contains('Sending')) {
            _statusH = 'अलर्ट भेज रहे हैं';
            _statusE = 'Sending emergency alerts...';
          } else if (s.contains('SOS') || s.contains('triggered')) {
            _statusH = 'मदद आ रही है!';
            _statusE = 'Help is on the way!';
          }
        });
      },
      onSosStateChange: (active) {
        if (!mounted) return;
        setState(() => _sosActive = active);
        if (active) {
          _pulseCtrl.repeat(reverse: true);
          _waveCtrl.repeat();
        } else {
          _pulseCtrl.stop();
          _waveCtrl.stop();
          _pulseCtrl.reset();
          _waveCtrl.reset();
        }
      },
      onCountdownStart: () {
        if (!mounted) return;
        setState(() => _countdownVisible = true);
      },
      onCountdownTick: (seconds) {},
      onCountdownCancel: () {
        if (!mounted) return;
        setState(() => _countdownVisible = false);
      },
    );

    _orbCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 10))..repeat();
    _orbAnim = Tween<double>(begin: 0, end: 1).animate(_orbCtrl);

    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _pulseAnim = Tween<double>(begin: 1.0, end: 1.09)
        .animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));

    _waveCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400));
    _waveAnim = Tween<double>(begin: 0, end: 1)
        .animate(CurvedAnimation(parent: _waveCtrl, curve: Curves.easeOut));

    _entryCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100));
    _entryAnim = CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOutQuint);
    _entryCtrl.forward();

    _idleCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 3))
      ..repeat(reverse: true);
    _idleAnim = Tween<double>(begin: 0.88, end: 1.0)
        .animate(CurvedAnimation(parent: _idleCtrl, curve: Curves.easeInOut));

    _scanCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 2))
      ..repeat();
    _scanAnim = Tween<double>(begin: 0, end: 1).animate(_scanCtrl);
  }

  // ── All original functions preserved exactly ──────────────────────

  Future<void> _toggleProtection() async {
    HapticFeedback.mediumImpact();
    if (_protected) {
      await _kavach.stopProtection();
      setState(() {
        _protected = false;
        _sosActive  = false;
        _recording  = false;
        _statusH    = 'आप सुरक्षित हैं';
        _statusE    = 'Protection is off • Tap to activate';
      });
    } else {
      setState(() => _statusE = 'Starting protection...');
      final ok = await _kavach.startProtection();
      if (ok) {
        setState(() {
          _protected = true;
          _statusH   = 'सुरक्षा चालू है';
          _statusE   = 'Listening for distress keywords';
        });
      }
    }
  }

  Future<void> _triggerSOS() async {
    HapticFeedback.heavyImpact();
    setState(() => _countdownVisible = true);
  }

  Future<void> _onCountdownComplete() async {
    if (!mounted) return;
    setState(() => _countdownVisible = false);
    setState(() {
      _sosActive = true;
      _statusH   = '🚨 मदद! एस.ओ.एस.!';
      _statusE   = 'SOS Triggered! Sending alerts...';
    });
    _pulseCtrl.repeat(reverse: true);
    _waveCtrl.repeat();
    await _kavach.immediateManualSOS();
  }

  void _onCountdownCancel() {
    _kavach.cancelCountdown();
    setState(() {
      _countdownVisible = false;
      _statusH = _protected ? 'सुरक्षा चालू है' : 'आप सुरक्षित हैं';
      _statusE = _protected ? 'Listening for keywords...' : 'Protection is off • Tap to activate';
    });
  }

  Future<void> _cancelSOS() async {
    HapticFeedback.mediumImpact();
    await _kavach.stopSOS();
    _pulseCtrl.stop();
    _waveCtrl.stop();
    _pulseCtrl.reset();
    _waveCtrl.reset();
    setState(() {
      _sosActive = false;
      _statusH   = _protected ? 'सुरक्षा चालू है' : 'आप सुरक्षित हैं';
      _statusE   = _protected ? 'Listening for keywords...' : 'Protection is off';
    });
  }

  @override
  void dispose() {
    _orbCtrl.dispose();
    _pulseCtrl.dispose();
    _waveCtrl.dispose();
    _entryCtrl.dispose();
    _idleCtrl.dispose();
    _scanCtrl.dispose();
    _stopFlutterSttOnly();
    _siren.dispose();
    _rec.dispose();
    super.dispose();
  }

  void _stopFlutterSttOnly() {
    _kavach.stopFlutterSTTOnly();
  }

  // ── COLOUR HELPERS ────────────────────────────────────────────────

  Color get _accentColor => _sosActive ? _crimson : _protected ? _emerald : _ember;

  Color get _glowColor => _sosActive
      ? _crimson.withValues(alpha: 0.45)
      : _protected
          ? _emerald.withValues(alpha: 0.35)
          : _ember.withValues(alpha: 0.28);

  // ── BUILD ─────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ));
    final mq   = MediaQuery.of(context);
    final size = mq.size;

    return Scaffold(
      backgroundColor: _bg,
      body: Stack(
        children: [
          // ── Background mesh ─────────────────────────────────────
          _NoiseMesh(accentColor: _accentColor),

          // ── Main content ────────────────────────────────────────
          AnimatedBuilder(
            animation: _entryAnim,
            builder: (_, child) => Opacity(
              opacity: _entryAnim.value,
              child: Transform.translate(
                offset: Offset(0, 36 * (1 - _entryAnim.value)),
                child: child,
              ),
            ),
            child: SafeArea(
              child: Column(
                children: [
                  _buildTopBar(),
                  SizedBox(height: size.height * 0.028),
                  _buildSOSOrb(size),
                  SizedBox(height: size.height * 0.026),
                  _buildStatusCard(),
                  const Spacer(),
                  _buildProtectionTile(),
                  const SizedBox(height: 12),
                  _buildBottomRow(),
                  SizedBox(height: mq.padding.bottom + 16),
                ],
              ),
            ),
          ),

          // ── Countdown overlay ───────────────────────────────────
          if (_countdownVisible)
            CountdownDialog(
              seconds: 3,
              onComplete: _onCountdownComplete,
              onCancel: _onCountdownCancel,
            ),
        ],
      ),
    );
  }

  // ── TOP BAR ──────────────────────────────────────────────────────

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 14, 20, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Logo mark
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: _accentColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _accentColor.withValues(alpha: 0.4), width: 1),
            ),
            child: Icon(Icons.shield_rounded, color: _accentColor, size: 18),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: 'KA',
                      style: TextStyle(
                        color: _accentColor,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 4,
                        fontFamily: 'monospace',
                      ),
                    ),
                    const TextSpan(
                      text: 'VACH',
                      style: TextStyle(
                        color: _textHigh,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 4,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                'कवच  •  आपकी सुरक्षा',
                style: TextStyle(color: _textMid, fontSize: 10.5, letterSpacing: 1.8),
              ),
            ],
          ),
          const Spacer(),
          // Contacts pill
          GestureDetector(
            onTap: () async {
              await Navigator.push(
                context,
                _pageRoute(ContactsScreen(contactService: widget.contactService)),
              );
              setState(() {});
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              decoration: BoxDecoration(
                color: _surface,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: _border, width: 1),
                boxShadow: [
                  BoxShadow(color: _accentColor.withValues(alpha: 0.08), blurRadius: 12),
                ],
              ),
              child: Row(
                children: [
                  Icon(Icons.people_alt_rounded, color: _textMid, size: 14),
                  const SizedBox(width: 6),
                  Text(
                    '${widget.contactService.contacts.length}/5',
                    style: TextStyle(
                      color: widget.contactService.contacts.isEmpty ? _crimson : _textHigh,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── SOS ORB ──────────────────────────────────────────────────────

  Widget _buildSOSOrb(Size size) {
    final double orbD = size.width * 0.52;

    return Center(
      child: GestureDetector(
        onTap: _sosActive ? _cancelSOS : _triggerSOS,
        onLongPress: _sosActive ? null : _triggerSOS,
        child: AnimatedBuilder(
          animation: Listenable.merge([_orbAnim, _pulseAnim, _waveAnim, _idleAnim, _scanAnim]),
          builder: (_, __) {
            return SizedBox(
              width: orbD + 100,
              height: orbD + 100,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Rotating dashed ring (outer)
                  Transform.rotate(
                    angle: _orbAnim.value * 2 * math.pi,
                    child: SizedBox(
                      width: orbD + 60,
                      height: orbD + 60,
                      child: CustomPaint(
                        painter: _SegmentRingPainter(
                          color: _accentColor.withValues(alpha: 0.2),
                          segments: 36,
                          gapRatio: 0.35,
                          strokeWidth: 1.2,
                        ),
                      ),
                    ),
                  ),

                  // Counter-rotating thin ring
                  Transform.rotate(
                    angle: -_orbAnim.value * 2 * math.pi * 0.6,
                    child: SizedBox(
                      width: orbD + 32,
                      height: orbD + 32,
                      child: CustomPaint(
                        painter: _SegmentRingPainter(
                          color: _accentColor.withValues(alpha: 0.12),
                          segments: 12,
                          gapRatio: 0.55,
                          strokeWidth: 1.0,
                        ),
                      ),
                    ),
                  ),

                  // SOS wave rings
                  if (_sosActive) ...[
                    _WaveRing(diameter: orbD * (1 + _waveAnim.value * 0.72), opacity: (1 - _waveAnim.value) * 0.22, color: _crimson),
                    _WaveRing(diameter: orbD * (1 + _waveAnim.value * 0.44), opacity: (1 - _waveAnim.value) * 0.30, color: _ember),
                  ],

                  // Idle breathing ring
                  if (!_sosActive)
                    Container(
                      width: orbD + 20,
                      height: orbD + 20,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _accentColor.withValues(alpha: _idleAnim.value * 0.14),
                          width: 1.5,
                        ),
                      ),
                    ),

                  // The orb itself
                  Transform.scale(
                    scale: _sosActive ? _pulseAnim.value : _idleAnim.value * 0.97 + 0.03,
                    child: Container(
                      width: orbD,
                      height: orbD,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          center: const Alignment(-0.3, -0.4),
                          radius: 0.85,
                          colors: _sosActive
                              ? [
                                  const Color(0xFFFF6B7A),
                                  const Color(0xFFE63946),
                                  const Color(0xFF9B1B26),
                                  const Color(0xFF5C0A12),
                                ]
                              : _protected
                                  ? [
                                      const Color(0xFF52F2BA),
                                      const Color(0xFF00C07F),
                                      const Color(0xFF006644),
                                      const Color(0xFF002E1F),
                                    ]
                                  : [
                                      const Color(0xFFFF9A6C),
                                      const Color(0xFFFF6B35),
                                      const Color(0xFFCC3D00),
                                      const Color(0xFF5C1800),
                                    ],
                          stops: const [0.0, 0.28, 0.65, 1.0],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: _accentColor.withValues(alpha: _sosActive ? 0.65 : 0.42),
                            blurRadius: _sosActive ? 60 : 40,
                            spreadRadius: _sosActive ? 14 : 6,
                            offset: const Offset(0, 8),
                          ),
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.5),
                            blurRadius: 30,
                            offset: const Offset(0, 14),
                          ),
                        ],
                      ),
                      child: ClipOval(
                        child: Stack(
                          children: [
                            // Scan line — only when protected & not SOS
                            if (_protected && !_sosActive)
                              Positioned(
                                top: orbD * _scanAnim.value - 2,
                                left: 0,
                                right: 0,
                                child: Container(
                                  height: 2,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        Colors.transparent,
                                        _emerald.withValues(alpha: 0.7),
                                        Colors.transparent,
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            // Orb content
                            Center(child: _OrbContent(sosActive: _sosActive, protected: _protected, accentColor: _accentColor)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  // ── STATUS CARD ──────────────────────────────────────────────────

  Widget _buildStatusCard() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _bgCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _accentColor.withValues(alpha: 0.25), width: 1),
        boxShadow: [
          BoxShadow(color: _accentColor.withValues(alpha: 0.10), blurRadius: 24, offset: const Offset(0, 4)),
        ],
      ),
      child: Row(
        children: [
          // Animated status dot
          AnimatedBuilder(
            animation: _idleAnim,
            builder: (_, __) => Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _accentColor.withValues(alpha: 0.15),
                  ),
                ),
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _accentColor,
                    boxShadow: [
                      BoxShadow(
                        color: _accentColor.withValues(alpha: _sosActive ? 0.9 : _idleAnim.value * 0.6),
                        blurRadius: 8,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 280),
                  transitionBuilder: (child, anim) => FadeTransition(
                    opacity: anim,
                    child: SlideTransition(
                      position: Tween(begin: const Offset(0, 0.3), end: Offset.zero).animate(anim),
                      child: child,
                    ),
                  ),
                  child: Text(
                    _statusH,
                    key: ValueKey(_statusH),
                    style: TextStyle(
                      color: _accentColor,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
                const SizedBox(height: 3),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 280),
                  child: Text(
                    _statusE,
                    key: ValueKey(_statusE),
                    style: const TextStyle(color: _textMid, fontSize: 11.5, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (_sosActive) _Pill(label: 'LIVE', color: _crimson),
          if (_recording && !_sosActive) _Pill(label: 'REC', color: _ember),
        ],
      ),
    );
  }

  // ── PROTECTION TILE ───────────────────────────────────────────────

  Widget _buildProtectionTile() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: GestureDetector(
        onTap: _toggleProtection,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          decoration: BoxDecoration(
            color: _protected ? _emerald.withValues(alpha: 0.07) : _bgCard,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: _protected ? _emerald.withValues(alpha: 0.35) : _border,
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: (_protected ? _emerald : Colors.transparent).withValues(alpha: 0.08),
                blurRadius: 20,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              // Icon container
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: _protected
                      ? _emerald.withValues(alpha: 0.15)
                      : _ember.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: _protected
                        ? _emerald.withValues(alpha: 0.3)
                        : _ember.withValues(alpha: 0.2),
                    width: 1,
                  ),
                ),
                child: Icon(
                  _protected ? Icons.hearing_rounded : Icons.hearing_disabled_rounded,
                  color: _protected ? _emerald : _ember,
                  size: 22,
                ),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _protected ? 'सुरक्षा सक्रिय है' : 'सुरक्षा शुरू करें',
                      style: TextStyle(
                        color: _protected ? _emerald : _textHigh,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _protected ? 'Tap to stop protection' : 'Tap to start protection mode',
                      style: const TextStyle(color: _textMid, fontSize: 11.5),
                    ),
                  ],
                ),
              ),
              _DarkToggle(active: _protected, activeColor: _emerald),
            ],
          ),
        ),
      ),
    );
  }

  // ── BOTTOM ROW ───────────────────────────────────────────────────

  Widget _buildBottomRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Expanded(
            child: _StatChip(
              icon: Icons.location_on_rounded,
              label: 'GPS',
              sub: 'सक्रिय',
              color: _gold,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: GestureDetector(
              onTap: () async {
                await Navigator.push(
                  context,
                  _pageRoute(ContactsScreen(contactService: widget.contactService)),
                );
                setState(() {});
              },
              child: _StatChip(
                icon: Icons.people_rounded,
                label: '${widget.contactService.contacts.length}',
                sub: 'संपर्क',
                color: widget.contactService.contacts.isEmpty ? _crimson : _emerald,
              ),
            ),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: _StatChip(
              icon: Icons.mic_rounded,
              label: '10m',
              sub: 'रिकॉर्ड',
              color: _teal,
            ),
          ),
        ],
      ),
    );
  }

  PageRoute _pageRoute(Widget page) {
    return PageRouteBuilder(
      pageBuilder: (_, __, ___) => page,
      transitionsBuilder: (_, anim, __, child) => SlideTransition(
        position: Tween(begin: const Offset(1.0, 0.0), end: Offset.zero)
            .animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
        child: child,
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// ORB CONTENT
// ═══════════════════════════════════════════════════════════════════

class _OrbContent extends StatelessWidget {
  final bool sosActive;
  final bool protected;
  final Color accentColor;
  const _OrbContent({required this.sosActive, required this.protected, required this.accentColor});

  @override
  Widget build(BuildContext context) {
    if (sosActive) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 1.5),
              color: Colors.white.withValues(alpha: 0.1),
            ),
            child: const Icon(Icons.stop_rounded, color: Colors.white, size: 26),
          ),
          const SizedBox(height: 10),
          const Text(
            'STOP',
            style: TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w900,
              letterSpacing: 5,
              fontFamily: 'monospace',
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'रोकें',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.65),
              fontSize: 12,
              letterSpacing: 2,
            ),
          ),
        ],
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 54,
          height: 54,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withValues(alpha: 0.25), width: 1.5),
            color: Colors.white.withValues(alpha: 0.12),
          ),
          child: const Icon(Icons.shield_rounded, color: Colors.white, size: 28),
        ),
        const SizedBox(height: 10),
        const Text(
          'KAVACH',
          style: TextStyle(
            color: Colors.white,
            fontSize: 17,
            fontWeight: FontWeight.w900,
            letterSpacing: 5,
            fontFamily: 'monospace',
          ),
        ),
        const SizedBox(height: 3),
        Text(
          'कवच',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.6),
            fontSize: 13,
            letterSpacing: 3,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.white.withValues(alpha: 0.22), width: 1),
            borderRadius: BorderRadius.circular(8),
            color: Colors.white.withValues(alpha: 0.08),
          ),
          child: Text(
            'PRESS IN EMERGENCY',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.85),
              fontSize: 7.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.8,
              fontFamily: 'monospace',
            ),
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// SMALL WIDGETS
// ═══════════════════════════════════════════════════════════════════

class _Pill extends StatelessWidget {
  final String label;
  final Color color;
  const _Pill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.45), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(shape: BoxShape.circle, color: color),
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 9,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.5,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }
}

class _DarkToggle extends StatelessWidget {
  final bool active;
  final Color activeColor;
  const _DarkToggle({required this.active, required this.activeColor});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: 50,
      height: 28,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: active ? activeColor.withValues(alpha: 0.25) : const Color(0xFF1E2130),
        border: Border.all(
          color: active ? activeColor.withValues(alpha: 0.6) : const Color(0xFF2E3248),
          width: 1,
        ),
        boxShadow: [
          if (active)
            BoxShadow(color: activeColor.withValues(alpha: 0.4), blurRadius: 12, spreadRadius: 0),
        ],
      ),
      child: Stack(
        children: [
          AnimatedPositioned(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            left: active ? 24 : 2,
            top: 2,
            child: Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: active ? activeColor : const Color(0xFF3A3F58),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.4),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String sub;
  final Color color;
  const _StatChip({required this.icon, required this.label, required this.sub, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        color: const Color(0xFF12151E),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.2), width: 1),
        boxShadow: [
          BoxShadow(color: color.withValues(alpha: 0.06), blurRadius: 12, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, color: color, size: 17),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 16,
              fontWeight: FontWeight.w900,
              fontFamily: 'monospace',
            ),
          ),
          Text(
            sub,
            style: const TextStyle(color: _textMid, fontSize: 10),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// WAVE RING (extracted for clarity)
// ═══════════════════════════════════════════════════════════════════

class _WaveRing extends StatelessWidget {
  final double diameter;
  final double opacity;
  final Color color;
  const _WaveRing({required this.diameter, required this.opacity, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: diameter,
      height: diameter,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: color.withValues(alpha: opacity.clamp(0.0, 1.0)),
          width: 2,
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// BACKGROUND NOISE MESH
// ═══════════════════════════════════════════════════════════════════

class _NoiseMesh extends StatelessWidget {
  final Color accentColor;
  const _NoiseMesh({required this.accentColor});

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: CustomPaint(
        painter: _MeshPainter(accentColor: accentColor),
      ),
    );
  }
}

class _MeshPainter extends CustomPainter {
  final Color accentColor;
  _MeshPainter({required this.accentColor});

  @override
  void paint(Canvas canvas, Size size) {
    // Top radial glow from accent
    final topGlow = Paint()
      ..shader = RadialGradient(
        center: Alignment.topCenter,
        radius: 0.7,
        colors: [
          accentColor.withValues(alpha: 0.10),
          Colors.transparent,
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height * 0.6));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height * 0.6), topGlow);

    // Bottom subtle glow
    final bottomGlow = Paint()
      ..shader = RadialGradient(
        center: Alignment.bottomCenter,
        radius: 0.5,
        colors: [
          accentColor.withValues(alpha: 0.05),
          Colors.transparent,
        ],
      ).createShader(Rect.fromLTWH(0, size.height * 0.6, size.width, size.height * 0.4));
    canvas.drawRect(Rect.fromLTWH(0, size.height * 0.6, size.width, size.height * 0.4), bottomGlow);

    // Subtle grid lines
    final gridPaint = Paint()
      ..color = const Color(0xFF1E2235)
      ..strokeWidth = 0.5;
    const gridSpacing = 44.0;
    for (double x = 0; x < size.width; x += gridSpacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = 0; y < size.height; y += gridSpacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }
  }

  @override
  bool shouldRepaint(_MeshPainter old) => old.accentColor != accentColor;
}

// ═══════════════════════════════════════════════════════════════════
// SEGMENT RING PAINTER (replaces _DashedHalo)
// ═══════════════════════════════════════════════════════════════════

class _SegmentRingPainter extends CustomPainter {
  final Color color;
  final int segments;
  final double gapRatio;
  final double strokeWidth;
  const _SegmentRingPainter({
    required this.color,
    required this.segments,
    required this.gapRatio,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - strokeWidth;
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final arcLen = (2 * math.pi) / segments;
    final fillRatio = 1 - gapRatio;
    for (int i = 0; i < segments; i++) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        i * arcLen,
        arcLen * fillRatio,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_SegmentRingPainter old) =>
      old.color != color || old.segments != segments;
}

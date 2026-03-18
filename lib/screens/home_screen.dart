import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/ai_service.dart';
import '../services/contact_service.dart';
import '../services/kavach_listener.dart';
import '../services/recording_service.dart';
import '../services/siren_service.dart';
import '../services/sos_service.dart';
import 'contacts_screen.dart';

// ═══════════════════════════════════════════════════════════════════
// KAVACH — "Sunrise India" Design System
//
// Philosophy: Premium consumer app, launch-ready, bright & bold.
// Like CRED × PhonePe × a safety product that people TRUST.
//
// Palette:
//   Cream     : #FFF8F0  (warm ivory background)
//   Card      : #FFFFFF  (pure white cards)
//   Saffron   : #FF6B2B  (Indian saffron, hero color)
//   Coral     : #FF8A50  (lighter saffron for gradients)
//   Crimson   : #D32F2F  (SOS danger)
//   Forest    : #2E7D32  (protection active, safe)
//   Mint      : #43A047  (lighter green)
//   Ink       : #1C1B20  (near-black text)
//   Slate     : #6B6880  (secondary text)
//   Divider   : #EDE8E0  (warm divider)
// ═══════════════════════════════════════════════════════════════════

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
  String _statusH = 'आप सुरक्षित हैं';
  String _statusE = 'Protection is off • Tap to activate';

  // ── Palette ───────────────────────────────────────────────────────
  static const Color _cream = Color(0xFFFFF8F0);
  static const Color _card = Color(0xFFFFFFFF);
  static const Color _saffron = Color(0xFFFF6B2B);
  static const Color _coral = Color(0xFFFF8A50);
  static const Color _crimson = Color(0xFFD32F2F);
  static const Color _forest = Color(0xFF2E7D32);
  static const Color _mint = Color(0xFF43A047);
  static const Color _ink = Color(0xFF1C1B20);
  static const Color _slate = Color(0xFF6B6880);
  static const Color _divider = Color(0xFFEDE8E0);

  // ── Animations ────────────────────────────────────────────────────
  late AnimationController _orbCtrl; // Rotating halo around button
  late AnimationController _pulseCtrl; // SOS heartbeat scale
  late AnimationController _waveCtrl; // Expanding SOS rings
  late AnimationController _entryCtrl; // Page entry stagger
  late AnimationController _idleCtrl; // Gentle idle glow

  late Animation<double> _orbAnim;
  late Animation<double> _pulseAnim;
  late Animation<double> _waveAnim;
  late Animation<double> _entryAnim;
  late Animation<double> _idleAnim;

  @override
  void initState() {
    super.initState();
    _sos = SOSService();
    _siren = SirenService();
    _rec = RecordingService();

    _kavach = KavachListener(
      sosService: _sos,
      sirenService: _siren,
      recordingService: _rec,
      contactService: widget.contactService,
      onStatusUpdate: (s) {
        if (!mounted) return;
        setState(() {
          if (s.contains('Listening') || s.contains('keyword')) {
            _statusH = 'सुन रहा हूँ...';
            _statusE = 'Listening for distress keywords';
          } else if (s.contains('Recording')) {
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
    );

    // Orb halo: slow full rotation
    _orbCtrl =
        AnimationController(vsync: this, duration: const Duration(seconds: 8))
          ..repeat();
    _orbAnim = Tween<double>(begin: 0, end: 1).animate(_orbCtrl);

    // SOS pulse: heartbeat
    _pulseCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 550));
    _pulseAnim = Tween<double>(begin: 1.0, end: 1.07)
        .animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));

    // Wave rings
    _waveCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200));
    _waveAnim = Tween<double>(begin: 0, end: 1)
        .animate(CurvedAnimation(parent: _waveCtrl, curve: Curves.easeOut));

    // Entry stagger
    _entryCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900));
    _entryAnim =
        CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOutCubic);
    _entryCtrl.forward();

    // Idle glow breathe
    _idleCtrl =
        AnimationController(vsync: this, duration: const Duration(seconds: 2))
          ..repeat(reverse: true);
    _idleAnim = Tween<double>(begin: 0.85, end: 1.0)
        .animate(CurvedAnimation(parent: _idleCtrl, curve: Curves.easeInOut));
  }

  Future<void> _toggleProtection() async {
    HapticFeedback.mediumImpact();
    if (_protected) {
      await _kavach.stopProtection();
      setState(() {
        _protected = false;
        _sosActive = false;
        _recording = false;
        _statusH = 'आप सुरक्षित हैं';
        _statusE = 'Protection is off • Tap to activate';
      });
    } else {
      setState(() => _statusE = 'Starting protection...');
      final ok = await _kavach.startProtection();
      if (ok) {
        setState(() {
          _protected = true;
          _statusH = 'सुरक्षा चालू है';
          _statusE = 'Listening for distress keywords';
        });
      }
    }
  }

  Future<void> _triggerSOS() async {
    HapticFeedback.heavyImpact();
    setState(() {
      _sosActive = true;
      _statusH = '🚨 मदद! एस.ओ.एस.!';
      _statusE = 'SOS Triggered! Sending alerts...';
    });
    _pulseCtrl.repeat(reverse: true);
    _waveCtrl.repeat();
    await _kavach.manualSOS();
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
      _statusH = _protected ? 'सुरक्षा चालू है' : 'आप सुरक्षित हैं';
      _statusE = _protected ? 'Listening for keywords...' : 'Protection is off';
    });
  }

  @override
  void dispose() {
    _orbCtrl.dispose();
    _pulseCtrl.dispose();
    _waveCtrl.dispose();
    _entryCtrl.dispose();
    _idleCtrl.dispose();
    _kavach.stopProtection();
    _siren.dispose();
    _rec.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ));
    final mq = MediaQuery.of(context);
    final size = mq.size;

    return Scaffold(
      backgroundColor: _cream,
      body: AnimatedBuilder(
        animation: _entryAnim,
        builder: (_, child) => Opacity(
          opacity: _entryAnim.value,
          child: Transform.translate(
            offset: Offset(0, 28 * (1 - _entryAnim.value)),
            child: child,
          ),
        ),
        child: Stack(
          children: [
            // ── Gradient background wash ─────────────────────────
            Positioned.fill(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 600),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: _sosActive
                        ? [
                            const Color(0xFFFFF0F0),
                            _cream,
                          ]
                        : _protected
                            ? [
                                const Color(0xFFF0FFF0),
                                _cream,
                              ]
                            : [
                                const Color(0xFFFFF5EC),
                                _cream,
                              ],
                    stops: const [0.0, 0.45],
                  ),
                ),
              ),
            ),

            // ── Top curved header shape ──────────────────────────
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: _TopCurve(
                color: _sosActive
                    ? _crimson
                    : _protected
                        ? _forest
                        : _saffron,
                height: size.height * 0.28,
              ),
            ),

            // ── Main content ─────────────────────────────────────
            SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildTopBar(),
                  SizedBox(height: size.height * 0.032),
                  _buildSOSOrb(size),
                  SizedBox(height: size.height * 0.03),
                  _buildStatusCard(),
                  const Spacer(),
                  _buildProtectionRow(),
                  const SizedBox(height: 12),
                  _buildBottomRow(),
                  SizedBox(height: mq.padding.bottom + 16),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── TOP BAR ──────────────────────────────────────────────────────

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 20, 0),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'KAVACH',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 6,
                  height: 1.0,
                ),
              ),
              const Text(
                'कवच  —  आपकी सुरक्षा',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 11,
                  letterSpacing: 1.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const Spacer(),
          GestureDetector(
            onTap: () async {
              await Navigator.push(
                context,
                _pageRoute(
                  ContactsScreen(contactService: widget.contactService),
                ),
              );
              setState(() {});
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: Colors.white.withOpacity(0.35),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.people_rounded,
                      color: Colors.white, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    '${widget.contactService.contacts.length}/5',
                    style: const TextStyle(
                      color: Colors.white,
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
    final double orbD = size.width * 0.54;

    return Center(
      child: GestureDetector(
        onTap: _sosActive ? _cancelSOS : _triggerSOS,
        onLongPress: _sosActive ? null : _triggerSOS,
        child: AnimatedBuilder(
          animation:
              Listenable.merge([_orbAnim, _pulseAnim, _waveAnim, _idleAnim]),
          builder: (_, __) {
            return SizedBox(
              width: orbD + 80,
              height: orbD + 80,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // ── Wave rings (SOS only) ───────────────────
                  if (_sosActive) ...[
                    _buildWaveRing(orbD * (1 + _waveAnim.value * 0.65),
                        (1 - _waveAnim.value) * 0.18, _crimson),
                    _buildWaveRing(orbD * (1 + _waveAnim.value * 0.42),
                        (1 - _waveAnim.value) * 0.25, _saffron),
                  ],

                  // ── Idle outer glow ring ───────────────────
                  if (!_sosActive)
                    Container(
                      width: orbD + 28,
                      height: orbD + 28,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: (_protected ? _forest : _saffron)
                              .withOpacity(_idleAnim.value * 0.18),
                          width: 1.5,
                        ),
                      ),
                    ),

                  // ── Rotating dashed halo ───────────────────
                  Transform.rotate(
                    angle: _orbAnim.value * 2 * math.pi,
                    child: SizedBox(
                      width: orbD + 14,
                      height: orbD + 14,
                      child: CustomPaint(
                        painter: _DashedHalo(
                          color: _sosActive
                              ? _crimson.withOpacity(0.5)
                              : _protected
                                  ? _forest.withOpacity(0.3)
                                  : _saffron.withOpacity(0.22),
                          segments: 24,
                        ),
                      ),
                    ),
                  ),

                  // ── Main orb ──────────────────────────────
                  Transform.scale(
                    scale: _sosActive
                        ? _pulseAnim.value
                        : _idleAnim.value * 0.98 + 0.02,
                    child: Container(
                      width: orbD,
                      height: orbD,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: _sosActive
                              ? [
                                  const Color(0xFFFF5252),
                                  const Color(0xFFE53935),
                                  const Color(0xFFB71C1C),
                                  const Color(0xFF8B0000),
                                ]
                              : _protected
                                  ? [
                                      const Color(0xFF66BB6A),
                                      const Color(0xFF43A047),
                                      const Color(0xFF2E7D32),
                                      const Color(0xFF1B5E20),
                                    ]
                                  : [
                                      const Color(0xFFFFAB76),
                                      _saffron,
                                      const Color(0xFFE64A19),
                                      const Color(0xFFBF360C),
                                    ],
                          stops: const [0.0, 0.3, 0.65, 1.0],
                          center: const Alignment(-0.25, -0.35),
                          radius: 0.9,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: (_sosActive
                                    ? _crimson
                                    : _protected
                                        ? _mint
                                        : _saffron)
                                .withOpacity(_sosActive ? 0.55 : 0.38),
                            blurRadius: _sosActive ? 48 : 32,
                            spreadRadius: _sosActive ? 10 : 4,
                            offset: const Offset(0, 6),
                          ),
                          BoxShadow(
                            color: Colors.black.withOpacity(0.12),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: _OrbContent(
                          sosActive: _sosActive, protected: _protected),
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

  Widget _buildWaveRing(double d, double opacity, Color color) {
    return Container(
      width: d,
      height: d,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: color.withOpacity(opacity.clamp(0.0, 1.0)),
          width: 2,
        ),
      ),
    );
  }

  // ── STATUS CARD ──────────────────────────────────────────────────

  Widget _buildStatusCard() {
    final Color accent = _sosActive
        ? _crimson
        : _protected
            ? _forest
            : _saffron;

    final Color bg = _sosActive
        ? const Color(0xFFFFF0F0)
        : _protected
            ? const Color(0xFFF0FFF1)
            : _card;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: accent.withOpacity(0.2),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: accent.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Animated dot
          AnimatedBuilder(
            animation: _idleAnim,
            builder: (_, __) => Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: accent,
                boxShadow: [
                  BoxShadow(
                    color: accent
                        .withOpacity(_sosActive ? 0.7 : _idleAnim.value * 0.5),
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: Text(
                    _statusH,
                    key: ValueKey(_statusH),
                    style: TextStyle(
                      color: accent,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: Text(
                    _statusE,
                    key: ValueKey(_statusE),
                    style: const TextStyle(
                      color: _slate,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Live / Rec badge
          if (_sosActive) _Badge(label: 'LIVE', color: _crimson),
          if (_recording && !_sosActive) _Badge(label: 'REC', color: _saffron),
        ],
      ),
    );
  }

  // ── PROTECTION ROW ───────────────────────────────────────────────

  Widget _buildProtectionRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: GestureDetector(
        onTap: _toggleProtection,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
          decoration: BoxDecoration(
            color: _protected ? _forest.withOpacity(0.06) : _card,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: _protected ? _forest.withOpacity(0.3) : _divider,
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: (_protected ? _forest : Colors.black).withOpacity(0.06),
                blurRadius: 16,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: _protected
                      ? _forest.withOpacity(0.12)
                      : _saffron.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(
                  _protected
                      ? Icons.hearing_rounded
                      : Icons.hearing_disabled_rounded,
                  color: _protected ? _mint : _saffron,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _protected ? 'सुरक्षा सक्रिय है' : 'सुरक्षा शुरू करें',
                      style: TextStyle(
                        color: _protected ? _forest : _ink,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      _protected
                          ? 'Tap to stop protection'
                          : 'Tap to start protection mode',
                      style: const TextStyle(color: _slate, fontSize: 11.5),
                    ),
                  ],
                ),
              ),
              _IOSToggle(active: _protected, activeColor: _mint),
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
          // GPS chip
          Expanded(
            child: _InfoChip(
              icon: Icons.location_on_rounded,
              label: 'GPS सक्रिय',
              sub: 'Location tracking',
              color: _saffron,
            ),
          ),
          const SizedBox(width: 10),
          // Contacts chip
          Expanded(
            child: GestureDetector(
              onTap: () async {
                await Navigator.push(
                  context,
                  _pageRoute(
                      ContactsScreen(contactService: widget.contactService)),
                );
                setState(() {});
              },
              child: _InfoChip(
                icon: Icons.people_rounded,
                label: '${widget.contactService.contacts.length} संपर्क',
                sub: widget.contactService.contacts.isEmpty
                    ? 'Add contacts →'
                    : 'SMS recipients',
                color:
                    widget.contactService.contacts.isEmpty ? _crimson : _forest,
              ),
            ),
          ),
          const SizedBox(width: 10),
          // Recording chip
          Expanded(
            child: _InfoChip(
              icon: Icons.mic_rounded,
              label: '10 मिनट',
              sub: 'Auto-recording',
              color: _slate,
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
        position: Tween(
          begin: const Offset(1.0, 0.0),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
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

  const _OrbContent({required this.sosActive, required this.protected});

  @override
  Widget build(BuildContext context) {
    if (sosActive) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.15),
            ),
            child:
                const Icon(Icons.stop_rounded, color: Colors.white, size: 28),
          ),
          const SizedBox(height: 8),
          const Text(
            'STOP',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w900,
              letterSpacing: 5,
            ),
          ),
          const Text(
            'रोकें',
            style: TextStyle(color: Colors.white70, fontSize: 13),
          ),
        ],
      );
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withOpacity(0.18),
          ),
          child:
              const Icon(Icons.shield_rounded, color: Colors.white, size: 28),
        ),
        const SizedBox(height: 8),
        const Text(
          'KAVACH',
          style: TextStyle(
            color: Colors.white,
            fontSize: 19,
            fontWeight: FontWeight.w900,
            letterSpacing: 5,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          'कवच',
          style: TextStyle(
            color: Colors.white.withOpacity(0.75),
            fontSize: 14,
            letterSpacing: 3,
            fontWeight: FontWeight.w400,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.18),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            'PRESS IN EMERGENCY',
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: 8,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5,
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

class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  const _Badge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.35), width: 1),
      ),
      child: Text(
        '● $label',
        style: TextStyle(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.5,
        ),
      ),
    );
  }
}

class _IOSToggle extends StatelessWidget {
  final bool active;
  final Color activeColor;
  const _IOSToggle({required this.active, required this.activeColor});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: 50,
      height: 28,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: active ? activeColor : const Color(0xFFDDD8D0),
        boxShadow: [
          if (active)
            BoxShadow(
                color: activeColor.withOpacity(0.35),
                blurRadius: 8,
                offset: const Offset(0, 2)),
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
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.18),
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

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String sub;
  final Color color;
  const _InfoChip(
      {required this.icon,
      required this.label,
      required this.sub,
      required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEDE8E0), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              color: color == const Color(0xFF6B6880)
                  ? const Color(0xFF1C1B20)
                  : color,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 1),
          Text(
            sub,
            style: const TextStyle(color: Color(0xFF6B6880), fontSize: 9.5),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// PAINTERS
// ═══════════════════════════════════════════════════════════════════

/// Curved top header shape
class _TopCurve extends StatelessWidget {
  final Color color;
  final double height;
  const _TopCurve({required this.color, required this.height});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 500),
      height: height,
      child: CustomPaint(
        painter: _TopCurvePainter(color: color),
        size: Size(double.infinity, height),
      ),
    );
  }
}

class _TopCurvePainter extends CustomPainter {
  final Color color;
  _TopCurvePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          color.withOpacity(0.95),
          color.withOpacity(0.75),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width, size.height * 0.72)
      ..cubicTo(
        size.width * 0.75,
        size.height * 1.05,
        size.width * 0.25,
        size.height * 1.05,
        0,
        size.height * 0.72,
      )
      ..close();

    canvas.drawPath(path, paint);

    // Subtle highlight shimmer on top
    final shimmer = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white.withOpacity(0.18),
          Colors.transparent,
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width * 0.6, size.height * 0.4));

    canvas.drawPath(path, shimmer);
  }

  @override
  bool shouldRepaint(_TopCurvePainter old) => old.color != color;
}

/// Rotating segmented arc halo
class _DashedHalo extends CustomPainter {
  final Color color;
  final int segments;
  const _DashedHalo({required this.color, required this.segments});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 1.5;
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final arcLen = (2 * math.pi) / segments;
    for (int i = 0; i < segments; i++) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        i * arcLen,
        arcLen * 0.55,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_DashedHalo old) => old.color != color;
}

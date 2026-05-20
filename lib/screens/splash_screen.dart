import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/kavach_colors.dart';

class SplashScreen extends StatefulWidget {
  final VoidCallback onComplete;
  const SplashScreen({super.key, required this.onComplete});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _shieldCtrl, _glowCtrl, _textCtrl, _ringCtrl, _fadeOutCtrl;
  late Animation<double> _shieldScale, _shieldOpacity, _glowAnim;
  late Animation<double> _textSlide, _textOpacity, _ringRotation, _ringOpacity, _fadeOut;

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ));

    _shieldCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));
    _shieldScale = Tween<double>(begin: 0.3, end: 1.0).animate(CurvedAnimation(parent: _shieldCtrl, curve: Curves.elasticOut));
    _shieldOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _shieldCtrl, curve: const Interval(0.0, 0.4, curve: Curves.easeOut)));

    _glowCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 2000));
    _glowAnim = Tween<double>(begin: 0.3, end: 1.0).animate(CurvedAnimation(parent: _glowCtrl, curve: Curves.easeInOut));

    _textCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _textSlide = Tween<double>(begin: 30.0, end: 0.0).animate(CurvedAnimation(parent: _textCtrl, curve: Curves.easeOutCubic));
    _textOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _textCtrl, curve: Curves.easeOut));

    _ringCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 10));
    _ringRotation = Tween<double>(begin: 0, end: 2 * math.pi).animate(_ringCtrl);
    _ringOpacity = Tween<double>(begin: 0.0, end: 0.6).animate(CurvedAnimation(parent: _shieldCtrl, curve: const Interval(0.3, 0.8, curve: Curves.easeOut)));

    _fadeOutCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _fadeOut = Tween<double>(begin: 1.0, end: 0.0).animate(CurvedAnimation(parent: _fadeOutCtrl, curve: Curves.easeIn));

    _startSequence();
  }

  Future<void> _startSequence() async {
    await Future.delayed(const Duration(milliseconds: 300));
    _shieldCtrl.forward();
    _ringCtrl.repeat();
    await Future.delayed(const Duration(milliseconds: 600));
    _glowCtrl.repeat(reverse: true);
    await Future.delayed(const Duration(milliseconds: 500));
    _textCtrl.forward();
    await Future.delayed(const Duration(milliseconds: 2000));
    if (!mounted) return;
    await _fadeOutCtrl.forward();
    if (!mounted) return;
    widget.onComplete();
  }

  @override
  void dispose() {
    _shieldCtrl.dispose(); _glowCtrl.dispose(); _textCtrl.dispose();
    _ringCtrl.dispose(); _fadeOutCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _fadeOut,
      builder: (_, child) => Opacity(opacity: _fadeOut.value, child: child),
      child: Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft, end: Alignment.bottomRight,
              colors: [Color(0xFF1A0F0A), Color(0xFF0D0D12), Color(0xFF150B06)],
            ),
          ),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildShieldLogo(),
                const SizedBox(height: 40),
                _buildTitle(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildShieldLogo() {
    return AnimatedBuilder(
      animation: Listenable.merge([_shieldScale, _glowAnim, _ringRotation, _ringOpacity]),
      builder: (_, __) => Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 220, height: 220,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(color: KavachColors.saffron.withValues(alpha: _glowAnim.value * 0.3), blurRadius: 80, spreadRadius: 20),
                BoxShadow(color: KavachColors.crimson.withValues(alpha: _glowAnim.value * 0.15), blurRadius: 120, spreadRadius: 40),
              ],
            ),
          ),
          Transform.rotate(
            angle: _ringRotation.value,
            child: Opacity(
              opacity: _ringOpacity.value,
              child: SizedBox(width: 200, height: 200, child: CustomPaint(painter: _DashedRing(color: KavachColors.saffron.withValues(alpha: 0.4), segments: 20))),
            ),
          ),
          Transform.rotate(
            angle: -_ringRotation.value * 0.7,
            child: Opacity(
              opacity: _ringOpacity.value * 0.5,
              child: SizedBox(width: 170, height: 170, child: CustomPaint(painter: _DashedRing(color: KavachColors.saffronLight.withValues(alpha: 0.25), segments: 12))),
            ),
          ),
          Transform.scale(
            scale: _shieldScale.value,
            child: Opacity(
              opacity: _shieldOpacity.value,
              child: Container(
                width: 130, height: 130,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const RadialGradient(
                    colors: [Color(0xFFFF8A50), KavachColors.saffron, Color(0xFFE55A1B), Color(0xFFBF360C)],
                    stops: [0.0, 0.3, 0.65, 1.0], center: Alignment(-0.25, -0.35), radius: 0.9,
                  ),
                  boxShadow: [BoxShadow(color: KavachColors.saffron.withValues(alpha: 0.5), blurRadius: 32, spreadRadius: 4)],
                ),
                child: const Icon(Icons.shield_rounded, color: Colors.white, size: 56),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTitle() {
    return AnimatedBuilder(
      animation: Listenable.merge([_textSlide, _textOpacity]),
      builder: (_, __) => Transform.translate(
        offset: Offset(0, _textSlide.value),
        child: Opacity(
          opacity: _textOpacity.value,
          child: Column(
            children: [
              const Text('KAVACH', style: TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.w900, letterSpacing: 12, height: 1.0)),
              const SizedBox(height: 8),
              Text('कवच  —  आपकी सुरक्षा', style: TextStyle(color: KavachColors.saffronLight.withValues(alpha: 0.8), fontSize: 14, letterSpacing: 2, fontWeight: FontWeight.w400)),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: KavachColors.saffron.withValues(alpha: 0.2)),
                ),
                child: Text('AI-POWERED EMERGENCY PROTECTION', style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 9, fontWeight: FontWeight.w600, letterSpacing: 2.5)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DashedRing extends CustomPainter {
  final Color color;
  final int segments;
  const _DashedRing({required this.color, required this.segments});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 1.5;
    final paint = Paint()..color = color..strokeWidth = 1.5..style = PaintingStyle.stroke;
    final arcLen = (2 * math.pi) / segments;
    for (int i = 0; i < segments; i++) {
      canvas.drawArc(Rect.fromCircle(center: center, radius: radius), i * arcLen, arcLen * 0.55, false, paint);
    }
  }

  @override
  bool shouldRepaint(_DashedRing old) => old.color != color;
}

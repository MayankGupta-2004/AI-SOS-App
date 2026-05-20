import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// CountdownDialog — 3-second SOS confirmation countdown
///
/// Shows a full-screen animated countdown before SOS triggers.
/// User can tap to cancel the countdown (prevents false positives).

class CountdownDialog extends StatefulWidget {
  final VoidCallback onComplete;
  final VoidCallback onCancel;
  final int seconds;

  const CountdownDialog({
    super.key,
    required this.onComplete,
    required this.onCancel,
    this.seconds = 3,
  });

  @override
  State<CountdownDialog> createState() => _CountdownDialogState();
}

class _CountdownDialogState extends State<CountdownDialog>
    with TickerProviderStateMixin {
  late AnimationController _progressCtrl;
  late AnimationController _pulseCtrl;
  late AnimationController _shakeCtrl;
  late Animation<double> _progressAnim;
  late Animation<double> _pulseAnim;

  int _currentSecond = 3;

  @override
  void initState() {
    super.initState();
    _currentSecond = widget.seconds;

    // Progress ring animation (fills over total duration)
    _progressCtrl = AnimationController(
      vsync: this,
      duration: Duration(seconds: widget.seconds),
    );
    _progressAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _progressCtrl, curve: Curves.linear),
    );

    // Pulse animation (heartbeat)
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 1.0, end: 1.12).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );

    // Shake animation
    _shakeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 80),
    );

    // Start countdown
    _progressCtrl.forward();
    _startTicking();

    // Haptic on start
    HapticFeedback.heavyImpact();
  }

  void _startTicking() {
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return false;

      setState(() {
        _currentSecond--;
      });

      // Haptic feedback each tick
      HapticFeedback.mediumImpact();
      _shakeCtrl.forward().then((_) => _shakeCtrl.reverse());

      if (_currentSecond <= 0) {
        widget.onComplete();
        return false;
      }
      return true;
    });
  }

  @override
  void dispose() {
    _progressCtrl.dispose();
    _pulseCtrl.dispose();
    _shakeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.85),
      child: GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          widget.onCancel();
        },
        child: SizedBox.expand(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Animated countdown circle
              AnimatedBuilder(
                animation: Listenable.merge([_progressAnim, _pulseAnim]),
                builder: (_, __) => Transform.scale(
                  scale: _pulseAnim.value,
                  child: SizedBox(
                    width: 200,
                    height: 200,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Background ring
                        SizedBox(
                          width: 200,
                          height: 200,
                          child: CircularProgressIndicator(
                            value: 1.0,
                            strokeWidth: 6,
                            color: Colors.white.withValues(alpha: 0.15),
                          ),
                        ),
                        // Animated progress ring
                        SizedBox(
                          width: 200,
                          height: 200,
                          child: CircularProgressIndicator(
                            value: _progressAnim.value,
                            strokeWidth: 6,
                            color: _getCountdownColor(),
                            strokeCap: StrokeCap.round,
                          ),
                        ),
                        // Countdown number
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 200),
                          transitionBuilder: (child, animation) =>
                              ScaleTransition(
                            scale: animation,
                            child: child,
                          ),
                          child: Text(
                            '$_currentSecond',
                            key: ValueKey(_currentSecond),
                            style: TextStyle(
                              color: _getCountdownColor(),
                              fontSize: 72,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -2,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 40),

              // Warning text
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: Text(
                  _getWarningText(),
                  key: ValueKey(_currentSecond),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                  ),
                ),
              ),

              const SizedBox(height: 12),

              Text(
                'SOS $_currentSecond सेकंड में शुरू होगा',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),

              const SizedBox(height: 48),

              // Cancel button
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.4),
                    width: 2,
                  ),
                  borderRadius: BorderRadius.circular(50),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.close_rounded,
                      color: Colors.white.withValues(alpha: 0.9),
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'TAP ANYWHERE TO CANCEL',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 2,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              Text(
                'रद्द करने के लिए कहीं भी टैप करें',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getCountdownColor() {
    if (_currentSecond <= 1) return const Color(0xFFFF1744);
    if (_currentSecond <= 2) return const Color(0xFFFF6B2B);
    return const Color(0xFFFFAB40);
  }

  String _getWarningText() {
    if (_currentSecond <= 1) return '🚨 TRIGGERING SOS...';
    if (_currentSecond <= 2) return '⚠️ SOS ALERT IMMINENT';
    return '⚠️ SOS COUNTDOWN';
  }
}

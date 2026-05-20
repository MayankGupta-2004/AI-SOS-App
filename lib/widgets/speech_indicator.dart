import 'package:flutter/material.dart';

/// SpeechIndicator — Animated waveform for speech recognition status
///
/// Shows animated bars when speech recognition is active,
/// creating a visual feedback that the app is listening.

class SpeechIndicator extends StatefulWidget {
  final bool isListening;
  final Color color;
  final double barWidth;
  final double maxHeight;

  const SpeechIndicator({
    super.key,
    required this.isListening,
    this.color = const Color(0xFF43A047),
    this.barWidth = 3.5,
    this.maxHeight = 24,
  });

  @override
  State<SpeechIndicator> createState() => _SpeechIndicatorState();
}

class _SpeechIndicatorState extends State<SpeechIndicator>
    with TickerProviderStateMixin {
  late final List<AnimationController> _controllers;
  late final List<Animation<double>> _animations;

  static const int _barCount = 5;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(_barCount, (i) {
      return AnimationController(
        vsync: this,
        duration: Duration(milliseconds: 400 + i * 80),
      );
    });

    _animations = _controllers.map((ctrl) {
      return Tween<double>(begin: 0.3, end: 1.0).animate(
        CurvedAnimation(parent: ctrl, curve: Curves.easeInOut),
      );
    }).toList();

    if (widget.isListening) _startAnimating();
  }

  @override
  void didUpdateWidget(SpeechIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isListening && !oldWidget.isListening) {
      _startAnimating();
    } else if (!widget.isListening && oldWidget.isListening) {
      _stopAnimating();
    }
  }

  void _startAnimating() {
    for (final ctrl in _controllers) {
      ctrl.repeat(reverse: true);
    }
  }

  void _stopAnimating() {
    for (final ctrl in _controllers) {
      ctrl.stop();
      ctrl.value = 0.3;
    }
  }

  @override
  void dispose() {
    for (final ctrl in _controllers) {
      ctrl.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List.generate(_barCount, (i) {
        return AnimatedBuilder(
          animation: _animations[i],
          builder: (_, __) {
            final height = widget.isListening
                ? widget.maxHeight * _animations[i].value
                : widget.maxHeight * 0.3;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              margin: EdgeInsets.symmetric(horizontal: widget.barWidth * 0.4),
              width: widget.barWidth,
              height: height,
              decoration: BoxDecoration(
                color: widget.color
                    .withValues(alpha: widget.isListening ? 0.9 : 0.3),
                borderRadius: BorderRadius.circular(widget.barWidth),
              ),
            );
          },
        );
      }),
    );
  }
}

/// PulsingDot — Simple pulsing dot indicator
class PulsingDot extends StatefulWidget {
  final Color color;
  final double size;

  const PulsingDot({
    super.key,
    this.color = const Color(0xFFD32F2F),
    this.size = 10,
  });

  @override
  State<PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<PulsingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: widget.color.withValues(alpha: _anim.value),
          boxShadow: [
            BoxShadow(
              color: widget.color.withValues(alpha: _anim.value * 0.5),
              blurRadius: 8,
              spreadRadius: 1,
            ),
          ],
        ),
      ),
    );
  }
}

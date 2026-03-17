import 'package:flutter/material.dart';

/// KavachButton — The main SOS button.
/// Shows "KAVACH" when idle, "STOP" when SOS is active.
/// Has a glowing red ring and pulsing shadow when active.

class KavachButton extends StatelessWidget {
  final bool isActive;

  const KavachButton({super.key, required this.isActive});

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Outer glow ring (visible when active)
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: isActive ? 230 : 210,
          height: isActive ? 230 : 210,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: isActive
                  ? Colors.red.withOpacity(0.4)
                  : Colors.white.withOpacity(0.08),
              width: isActive ? 3 : 1.5,
            ),
          ),
        ),

        // Middle ring
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: isActive ? 210 : 195,
          height: isActive ? 210 : 195,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: isActive
                  ? Colors.red.withOpacity(0.6)
                  : Colors.white.withOpacity(0.15),
              width: isActive ? 2 : 1,
            ),
          ),
        ),

        // Main button circle
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: 185,
          height: 185,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: isActive
                  ? [
                      const Color(0xFFFF1744),
                      const Color(0xFFB71C1C),
                    ]
                  : [
                      const Color(0xFFD32F2F),
                      const Color(0xFF7F0000),
                    ],
              center: const Alignment(-0.3, -0.3),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.red.withOpacity(isActive ? 0.7 : 0.4),
                blurRadius: isActive ? 40 : 20,
                spreadRadius: isActive ? 10 : 4,
              ),
              BoxShadow(
                color: Colors.black.withOpacity(0.5),
                blurRadius: 15,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Shield icon
              Icon(
                isActive ? Icons.stop_rounded : Icons.shield,
                color: Colors.white,
                size: isActive ? 36 : 32,
              ),
              const SizedBox(height: 6),
              // Label
              Text(
                isActive ? 'STOP' : 'KAVACH',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: isActive ? 16 : 22,
                  fontWeight: FontWeight.w900,
                  letterSpacing: isActive ? 4 : 6,
                ),
              ),
              if (!isActive) ...[
                const SizedBox(height: 2),
                Text(
                  'कवच',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.6),
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

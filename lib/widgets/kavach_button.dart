import 'package:flutter/material.dart';

class KavachButton extends StatelessWidget {
  final bool isActive;
  const KavachButton({super.key, required this.isActive});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 195,
      height: 195,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: isActive
              ? [const Color(0xFFFF4560), const Color(0xFFBD0000)]
              : [const Color(0xFFFF6B00), const Color(0xFFFF1744)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color:
                (isActive ? const Color(0xFFFF1744) : const Color(0xFFFF4500))
                    .withOpacity(0.45),
            blurRadius: 35,
            spreadRadius: 8,
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isActive ? Icons.stop_rounded : Icons.shield_rounded,
              color: Colors.white,
              size: 30,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            isActive ? 'STOP' : 'KAVACH',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w900,
              letterSpacing: 4,
            ),
          ),
          Text(
            isActive ? 'रोकें' : 'कवच',
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 14,
              letterSpacing: 2,
            ),
          ),
        ],
      ),
    );
  }
}

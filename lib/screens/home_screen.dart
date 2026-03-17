import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/ai_service.dart';
import '../services/contact_service.dart';
import '../services/kavach_listener.dart';
import '../services/recording_service.dart';
import '../services/siren_service.dart';
import '../services/sos_service.dart';
import '../widgets/kavach_button.dart';
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

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  late final SOSService _sosService;
  late final SirenService _sirenService;
  late final RecordingService _recordingService;
  late final KavachListener _kavachListener;

  bool _protectionMode = false;
  bool _sosActive = false;
  String _statusText = 'Stay Safe. Press Kavach in emergency.';

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();

    _sosService = SOSService();
    _sirenService = SirenService();
    _recordingService = RecordingService();

    _kavachListener = KavachListener(
      sosService: _sosService,
      sirenService: _sirenService,
      recordingService: _recordingService,
      contactService: widget.contactService,
      // Live status updates feed directly into UI
      onStatusUpdate: (status) {
        if (mounted) {
          setState(() {
            _statusText = status;
            // Track SOS state from status string
            if (status.contains('SOS') ||
                status.contains('Siren') ||
                status.contains('Sending') ||
                status.contains('Recording')) {
              _sosActive = true;
            }
          });
        }
      },
    );

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  // ─────────────────────────────────────────────────────
  // PROTECTION MODE TOGGLE
  // ─────────────────────────────────────────────────────

  Future<void> _toggleProtection() async {
    if (_protectionMode) {
      // TURN OFF
      await _kavachListener.stopProtection();
      setState(() {
        _protectionMode = false;
        _sosActive = false;
        _statusText = 'Stay Safe. Press Kavach in emergency.';
      });
    } else {
      // TURN ON
      setState(() => _statusText = 'Starting protection...');
      final started = await _kavachListener.startProtection();
      if (started) {
        setState(() {
          _protectionMode = true;
          _statusText = 'Listening for distress keywords...';
        });
      } else {
        setState(() => _statusText = 'Could not start mic. Check permissions.');
        _showSnack('Microphone permission required for protection mode.');
      }
    }
  }

  // ─────────────────────────────────────────────────────
  // MANUAL SOS (Kavach button)
  // ─────────────────────────────────────────────────────

  Future<void> _triggerManualSOS() async {
    HapticFeedback.heavyImpact();
    setState(() {
      _sosActive = true;
      _statusText = '🚨 SOS TRIGGERED...';
    });
    await _kavachListener.manualSOS();
  }

  // ─────────────────────────────────────────────────────
  // STOP SOS
  // ─────────────────────────────────────────────────────

  Future<void> _stopSOS() async {
    await _kavachListener.stopSOS();
    setState(() {
      _sosActive = false;
      _statusText = _protectionMode
          ? 'Listening for distress keywords...'
          : 'Stay Safe. Press Kavach in emergency.';
    });
    if (_recordingService.isRecording) {
      _showSnack('Siren stopped. Background recording continues (10 min).');
    }
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        duration: const Duration(seconds: 4),
        backgroundColor: const Color(0xFF1A1A1A),
      ),
    );
  }

  @override
  void dispose() {
    _kavachListener.stopProtection();
    _sirenService.dispose();
    _recordingService.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'KAVACH',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: 22,
            letterSpacing: 6,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.contacts, color: Colors.white70),
            tooltip: 'Emergency Contacts',
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      ContactsScreen(contactService: widget.contactService),
                ),
              );
              // Refresh contact count after returning
              setState(() {});
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // ── Live status bar ──────────────────────────────────
            _buildStatusBar(),

            const Spacer(),

            // ── Kavach SOS button ────────────────────────────────
            _buildKavachSection(),

            const SizedBox(height: 48),

            // ── Protection mode toggle ───────────────────────────
            _buildProtectionToggle(),

            const SizedBox(height: 20),

            // ── Recording indicator ──────────────────────────────
            if (_recordingService.isRecording) _buildRecordingBadge(),

            const Spacer(),

            // ── Bottom contact count ─────────────────────────────
            _buildBottomInfo(),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────
  // WIDGETS
  // ─────────────────────────────────────────────────────

  Widget _buildStatusBar() {
    final Color dotColor = _sosActive
        ? Colors.red
        : _protectionMode
            ? Colors.greenAccent
            : Colors.grey;

    final Color barColor = _sosActive
        ? Colors.red.withOpacity(0.15)
        : _protectionMode
            ? Colors.green.withOpacity(0.1)
            : Colors.white.withOpacity(0.04);

    final Color borderColor = _sosActive
        ? Colors.red.withOpacity(0.5)
        : _protectionMode
            ? Colors.greenAccent.withOpacity(0.3)
            : Colors.white12;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: barColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          // Blinking indicator dot
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.3, end: 1.0),
            duration: const Duration(milliseconds: 700),
            builder: (_, opacity, __) => Opacity(
              opacity: _sosActive ? opacity : 1.0,
              child: Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: dotColor,
                  boxShadow: _sosActive
                      ? [
                          BoxShadow(
                              color: Colors.red.withOpacity(0.6), blurRadius: 6)
                        ]
                      : null,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _statusText,
              style: TextStyle(
                color: _sosActive
                    ? Colors.redAccent
                    : _protectionMode
                        ? Colors.greenAccent
                        : Colors.white54,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKavachSection() {
    return Column(
      children: [
        Text(
          _sosActive ? 'TAP TO STOP SOS' : 'PRESS IN EMERGENCY',
          style: TextStyle(
            color: Colors.white.withOpacity(0.35),
            fontSize: 11,
            letterSpacing: 3,
          ),
        ),
        const SizedBox(height: 20),
        GestureDetector(
          onTap: _sosActive ? _stopSOS : _triggerManualSOS,
          onLongPress: _sosActive ? null : _triggerManualSOS,
          child: AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (_, child) => Transform.scale(
              scale: _sosActive ? _pulseAnimation.value : 1.0,
              child: child,
            ),
            child: KavachButton(isActive: _sosActive),
          ),
        ),
      ],
    );
  }

  Widget _buildProtectionToggle() {
    return GestureDetector(
      onTap: _toggleProtection,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: 240,
        padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 24),
        decoration: BoxDecoration(
          color: _protectionMode
              ? Colors.green.withOpacity(0.12)
              : Colors.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(50),
          border: Border.all(
            color: _protectionMode
                ? Colors.greenAccent.withOpacity(0.6)
                : Colors.white24,
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _protectionMode ? Icons.shield : Icons.shield_outlined,
              color: _protectionMode ? Colors.greenAccent : Colors.white54,
              size: 20,
            ),
            const SizedBox(width: 10),
            Text(
              _protectionMode ? 'Protection ON' : 'Start Protection',
              style: TextStyle(
                color: _protectionMode ? Colors.greenAccent : Colors.white70,
                fontWeight: FontWeight.w700,
                fontSize: 15,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecordingBadge() {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.orange.withOpacity(0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.fiber_manual_record, color: Colors.orange, size: 12),
          const SizedBox(width: 6),
          Text(
            'Recording in background — 10 min',
            style: TextStyle(
              color: Colors.orange.withOpacity(0.9),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomInfo() {
    final count = widget.contactService.contacts.length;
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: GestureDetector(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                ContactsScreen(contactService: widget.contactService),
          ),
        ),
        child: Text(
          count == 0
              ? '⚠️ No emergency contacts — tap to add'
              : '$count emergency contact${count > 1 ? 's' : ''} saved',
          style: TextStyle(
            color: count == 0 ? Colors.orange : Colors.white30,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}

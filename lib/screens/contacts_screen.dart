import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/contact_service.dart';

class ContactsScreen extends StatefulWidget {
  final ContactService contactService;
  const ContactsScreen({super.key, required this.contactService});

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen>
    with SingleTickerProviderStateMixin {
  static const Color _cream = Color(0xFFFFF8F0);
  static const Color _card = Color(0xFFFFFFFF);
  static const Color _saffron = Color(0xFFFF6B2B);
  static const Color _coral = Color(0xFFFF8A50);
  static const Color _crimson = Color(0xFFD32F2F);
  static const Color _forest = Color(0xFF2E7D32);
  static const Color _ink = Color(0xFF1C1B20);
  static const Color _slate = Color(0xFF6B6880);
  static const Color _divider = Color(0xFFEDE8E0);

  final List<List<Color>> _avGrads = [
    [const Color(0xFFFF6B2B), const Color(0xFFBF360C)],
    [const Color(0xFF1565C0), const Color(0xFF0D47A1)],
    [const Color(0xFF2E7D32), const Color(0xFF1B5E20)],
    [const Color(0xFF6A1B9A), const Color(0xFF4A148C)],
    [const Color(0xFF00838F), const Color(0xFF006064)],
  ];

  void _showSheet({int? editIndex}) {
    final nc = TextEditingController(
        text: editIndex != null
            ? widget.contactService.contacts[editIndex].name
            : '');
    final pc = TextEditingController(
        text: editIndex != null
            ? widget.contactService.contacts[editIndex].phone
            : '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          decoration: const BoxDecoration(
            color: _card,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 36),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: _divider,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              // Sheet header
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [_saffron, _coral],
                      ),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: _saffron.withOpacity(0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.person_add_rounded,
                        color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        editIndex != null ? 'संपर्क बदलें' : 'नया संपर्क',
                        style: const TextStyle(
                          color: _ink,
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        editIndex != null
                            ? 'Edit contact details'
                            : 'Add emergency contact',
                        style: const TextStyle(color: _slate, fontSize: 12),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 24),
              // Name field
              _Field(
                  ctrl: nc,
                  hint: 'Full Name  •  पूरा नाम',
                  icon: Icons.person_outline_rounded),
              const SizedBox(height: 12),
              // Phone field
              _Field(
                  ctrl: pc,
                  hint: 'Phone Number  •  +91XXXXXXXXXX',
                  icon: Icons.phone_outlined,
                  type: TextInputType.phone),
              const SizedBox(height: 24),
              // Action buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        side: const BorderSide(color: _divider, width: 1.5),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                      child: const Text(
                        'रद्द करें',
                        style: TextStyle(
                            color: _slate, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: () async {
                        final n = nc.text.trim();
                        final p = pc.text.trim();
                        if (n.isEmpty || p.isEmpty) return;
                        HapticFeedback.lightImpact();
                        final c = EmergencyContact(name: n, phone: p);
                        if (editIndex != null) {
                          await widget.contactService
                              .updateContact(editIndex, c);
                        } else {
                          await widget.contactService.addContact(c);
                        }
                        setState(() {});
                        Navigator.pop(ctx);
                      },
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        backgroundColor: _saffron,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                        shadowColor: _saffron.withOpacity(0.4),
                      ),
                      child: Text(
                        editIndex != null ? 'Save' : 'जोड़ें',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final contacts = widget.contactService.contacts;
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ));

    return Scaffold(
      backgroundColor: _cream,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 12, 20, 0),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: _card,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _divider, width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      child: const Icon(Icons.arrow_back_ios_new_rounded,
                          color: _ink, size: 14),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'आपातकालीन संपर्क',
                        style: TextStyle(
                          color: _ink,
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        'Emergency Contacts',
                        style: TextStyle(color: _slate, fontSize: 12),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ── Summary banner ────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      _saffron.withOpacity(0.1),
                      _coral.withOpacity(0.05),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: _saffron.withOpacity(0.2),
                    width: 1.5,
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '${contacts.length}',
                                style: const TextStyle(
                                  color: _saffron,
                                  fontSize: 36,
                                  fontWeight: FontWeight.w900,
                                  height: 1.0,
                                ),
                              ),
                              const Padding(
                                padding: EdgeInsets.only(bottom: 4, left: 4),
                                child: Text(
                                  '/ 5 संपर्क',
                                  style: TextStyle(
                                    color: _ink,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: contacts.length / 5,
                              backgroundColor: _saffron.withOpacity(0.12),
                              valueColor:
                                  const AlwaysStoppedAnimation<Color>(_saffron),
                              minHeight: 5,
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'SMS with GPS location sent on SOS',
                            style: TextStyle(color: _slate, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: _card,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: _divider, width: 1),
                      ),
                      child: const Icon(Icons.sms_rounded,
                          color: _saffron, size: 26),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // ── Contact list ──────────────────────────────────────
            Expanded(
              child: contacts.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 88,
                            height: 88,
                            decoration: BoxDecoration(
                              color: _saffron.withOpacity(0.08),
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: _saffron.withOpacity(0.2), width: 1.5),
                            ),
                            child: Icon(Icons.people_outline_rounded,
                                size: 40, color: _saffron.withOpacity(0.7)),
                          ),
                          const SizedBox(height: 20),
                          const Text(
                            'कोई संपर्क नहीं',
                            style: TextStyle(
                              color: _ink,
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Add contacts to receive SOS alerts',
                            style: TextStyle(color: _slate, fontSize: 13),
                          ),
                          const SizedBox(height: 28),
                          GestureDetector(
                            onTap: _showSheet,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 32, vertical: 15),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                    colors: [_saffron, _coral]),
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: _saffron.withOpacity(0.35),
                                    blurRadius: 20,
                                    offset: const Offset(0, 6),
                                  ),
                                ],
                              ),
                              child: const Text(
                                'पहला संपर्क जोड़ें',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: contacts.length,
                      itemBuilder: (_, i) {
                        final c = contacts[i];
                        final grad = _avGrads[i % _avGrads.length];
                        return TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0.0, end: 1.0),
                          duration: Duration(milliseconds: 200 + i * 70),
                          curve: Curves.easeOutCubic,
                          builder: (_, v, child) => Opacity(
                            opacity: v,
                            child: Transform.translate(
                              offset: Offset(0, 16 * (1 - v)),
                              child: child,
                            ),
                          ),
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: _card,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(color: _divider, width: 1.5),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.04),
                                  blurRadius: 10,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                // Avatar
                                Container(
                                  width: 50,
                                  height: 50,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: grad,
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    borderRadius: BorderRadius.circular(14),
                                    boxShadow: [
                                      BoxShadow(
                                        color: grad[0].withOpacity(0.3),
                                        blurRadius: 8,
                                        offset: const Offset(0, 3),
                                      ),
                                    ],
                                  ),
                                  child: Center(
                                    child: Text(
                                      c.name.isNotEmpty
                                          ? c.name[0].toUpperCase()
                                          : '?',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w900,
                                        fontSize: 20,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        c.name,
                                        style: const TextStyle(
                                          color: _ink,
                                          fontSize: 15,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Row(
                                        children: [
                                          const Icon(Icons.phone_rounded,
                                              size: 11, color: _slate),
                                          const SizedBox(width: 4),
                                          Text(c.phone,
                                              style: const TextStyle(
                                                  color: _slate, fontSize: 12)),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                // Edit
                                _ActBtn(
                                  icon: Icons.edit_rounded,
                                  color: const Color(0xFF1565C0),
                                  bg: const Color(0xFFE3F2FD),
                                  onTap: () => _showSheet(editIndex: i),
                                ),
                                const SizedBox(width: 8),
                                // Delete
                                _ActBtn(
                                  icon: Icons.delete_rounded,
                                  color: _crimson,
                                  bg: const Color(0xFFFFEBEE),
                                  onTap: () async {
                                    HapticFeedback.lightImpact();
                                    await widget.contactService
                                        .removeContact(i);
                                    setState(() {});
                                  },
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: contacts.length < ContactService.maxContacts
          ? FloatingActionButton.extended(
              onPressed: _showSheet,
              backgroundColor: _saffron,
              elevation: 4,
              icon: const Icon(Icons.add_rounded, color: Colors.white),
              label: const Text(
                'संपर्क जोड़ें',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                ),
              ),
            )
          : null,
    );
  }
}

// ── Shared reusables ──────────────────────────────────────────────

class _Field extends StatelessWidget {
  final TextEditingController ctrl;
  final String hint;
  final IconData icon;
  final TextInputType type;
  const _Field({
    required this.ctrl,
    required this.hint,
    required this.icon,
    this.type = TextInputType.text,
  });

  @override
  Widget build(BuildContext context) {
    const saffron = Color(0xFFFF6B2B);
    const divider = Color(0xFFEDE8E0);
    const ink = Color(0xFF1C1B20);
    const slate = Color(0xFF6B6880);

    return TextField(
      controller: ctrl,
      keyboardType: type,
      style: const TextStyle(
          color: ink, fontSize: 15, fontWeight: FontWeight.w600),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Color(0xFFBBB0A8), fontSize: 13),
        prefixIcon: Icon(icon, color: saffron.withOpacity(0.7), size: 20),
        filled: true,
        fillColor: const Color(0xFFFFF8F0),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: divider, width: 1.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: divider, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: saffron, width: 2),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      ),
    );
  }
}

class _ActBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final Color bg;
  final VoidCallback onTap;
  const _ActBtn(
      {required this.icon,
      required this.color,
      required this.bg,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(11),
        ),
        child: Icon(icon, color: color, size: 17),
      ),
    );
  }
}

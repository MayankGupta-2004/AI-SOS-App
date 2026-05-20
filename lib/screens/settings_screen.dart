import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../main.dart'; // FIX: themeModeNotifier
import '../theme/kavach_colors.dart';
import '../services/permission_service.dart';

/// SettingsScreen — Modern premium settings UI
///
/// Privacy controls, AI sensitivity, language switching,
/// battery optimization, permissions, dark mode, accessibility.

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // FIX: _darkMode now mirrors themeModeNotifier, not local-only state
  bool _darkMode = false;
  bool _hapticFeedback = true;
  bool _autoRecord = true;
  bool _locationSharing = true;

  // FIX: _aiSensitivity now loaded from + saved to SharedPreferences
  double _aiSensitivity = 0.85;

  static const String _prefsDarkMode = 'kavach_theme';
  static const String _prefsSensitivity = 'kavach_ai_sensitivity';
  static const String _prefsHaptic = 'kavach_haptic';
  static const String _prefsAutoRecord = 'kavach_auto_record';
  static const String _prefsLocation = 'kavach_location_sharing';

  @override
  void initState() {
    super.initState();
    // FIX: read ALL settings from prefs on open so they survive app restarts
    _loadSettings();

    // FIX: sync _darkMode with current live notifier value
    _darkMode = themeModeNotifier.value == ThemeMode.dark;
  }

  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;
      setState(() {
        // Theme
        final saved = prefs.getString(_prefsDarkMode) ?? 'system';
        _darkMode = saved == 'dark';

        // AI sensitivity — FIX: was never loaded, lost on every open
        _aiSensitivity = prefs.getDouble(_prefsSensitivity) ?? 0.85;

        // Other toggles
        _hapticFeedback = prefs.getBool(_prefsHaptic) ?? true;
        _autoRecord = prefs.getBool(_prefsAutoRecord) ?? true;
        _locationSharing = prefs.getBool(_prefsLocation) ?? true;
      });
    } catch (e) {
      debugPrint('[Settings] Load failed: $e');
    }
  }

  // FIX: saves a single key-value pair immediately
  Future<void> _savePref(String key, dynamic value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (value is bool) await prefs.setBool(key, value);
      if (value is double) await prefs.setDouble(key, value);
      if (value is String) await prefs.setString(key, value);
    } catch (e) {
      debugPrint('[Settings] Save failed: $e');
    }
  }

  // FIX: dark mode now actually changes the app theme globally
  void _onDarkModeChanged(bool v) {
    setState(() => _darkMode = v);
    // Write to the global notifier — MaterialApp reacts instantly
    themeModeNotifier.value = v ? ThemeMode.dark : ThemeMode.light;
    // Persist so it's restored on next launch (read in main.dart Step 6)
    _savePref(_prefsDarkMode, v ? 'dark' : 'light');
  }

  // FIX: AI sensitivity persisted immediately on every slider change
  void _onSensitivityChanged(double v) {
    setState(() => _aiSensitivity = v);
    _savePref(_prefsSensitivity, v);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? KavachColors.darkBg : KavachColors.cream;
    final cardBg = isDark ? KavachColors.darkCard : KavachColors.cardLight;
    final textColor = isDark ? Colors.white : KavachColors.ink;
    final subtextColor =
        isDark ? KavachColors.textOnDarkMuted : KavachColors.slate;
    final borderColor =
        isDark ? KavachColors.dividerDark : KavachColors.divider;

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──────────────────────────────────────────
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
                        color: cardBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: borderColor, width: 1.5),
                      ),
                      child: Icon(
                        Icons.arrow_back_ios_new_rounded,
                        color: textColor,
                        size: 14,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'सेटिंग्स',
                        style: TextStyle(
                          color: textColor,
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        'Settings',
                        style: TextStyle(color: subtextColor, fontSize: 12),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: [
                  // ── Safety ──────────────────────────────────────
                  _SectionHeader(
                    title: 'Safety',
                    subtitle: 'सुरक्षा',
                    isDark: isDark,
                  ),
                  const SizedBox(height: 10),
                  _SettingsCard(
                    cardBg: cardBg,
                    borderColor: borderColor,
                    children: [
                      _ToggleTile(
                        icon: Icons.mic_rounded,
                        iconColor: KavachColors.saffron,
                        title: 'Auto Record',
                        subtitle: 'Record audio on SOS trigger',
                        value: _autoRecord,
                        onChanged: (v) {
                          setState(() => _autoRecord = v);
                          _savePref(_prefsAutoRecord, v);
                        },
                        isDark: isDark,
                      ),
                      _Divider(color: borderColor),
                      _ToggleTile(
                        icon: Icons.location_on_rounded,
                        iconColor: KavachColors.forest,
                        title: 'Live Location',
                        subtitle: 'Share GPS with contacts',
                        value: _locationSharing,
                        onChanged: (v) {
                          setState(() => _locationSharing = v);
                          _savePref(_prefsLocation, v);
                        },
                        isDark: isDark,
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // ── AI Detection ─────────────────────────────────
                  _SectionHeader(
                    title: 'AI Detection',
                    subtitle: 'AI पहचान',
                    isDark: isDark,
                  ),
                  const SizedBox(height: 10),
                  _SettingsCard(
                    cardBg: cardBg,
                    borderColor: borderColor,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: KavachColors.saffron
                                        .withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(
                                    Icons.psychology_rounded,
                                    color: KavachColors.saffron,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'AI Sensitivity',
                                        style: TextStyle(
                                          color: isDark
                                              ? Colors.white
                                              : KavachColors.ink,
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      // FIX: shows live value that is now persisted
                                      Text(
                                        '${(_aiSensitivity * 100).toInt()}% — '
                                        '${_aiSensitivity > 0.8 ? "High" : _aiSensitivity > 0.5 ? "Medium" : "Low"}',
                                        style: TextStyle(
                                          color: subtextColor,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                // Visual sensitivity badge
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _sensitivityColor.withValues(
                                        alpha: 0.15),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: _sensitivityColor.withValues(
                                          alpha: 0.4),
                                      width: 1,
                                    ),
                                  ),
                                  child: Text(
                                    _sensitivityLabel,
                                    style: TextStyle(
                                      color: _sensitivityColor,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 1,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            SliderTheme(
                              data: SliderThemeData(
                                activeTrackColor: _sensitivityColor,
                                inactiveTrackColor:
                                    _sensitivityColor.withValues(alpha: 0.15),
                                thumbColor: _sensitivityColor,
                                overlayColor:
                                    _sensitivityColor.withValues(alpha: 0.1),
                                trackHeight: 4,
                              ),
                              // FIX: _onSensitivityChanged now persists the value
                              child: Slider(
                                value: _aiSensitivity,
                                min: 0.3,
                                max: 1.0,
                                divisions: 7,
                                onChanged: _onSensitivityChanged,
                              ),
                            ),
                            // Helper text
                            Text(
                              _aiSensitivity > 0.8
                                  ? 'High: triggers on any keyword match'
                                  : _aiSensitivity > 0.5
                                      ? 'Medium: balanced detection'
                                      : 'Low: only clear distress phrases',
                              style: TextStyle(
                                color: subtextColor,
                                fontSize: 10.5,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // ── Appearance ───────────────────────────────────
                  _SectionHeader(
                    title: 'Appearance',
                    subtitle: 'दिखावट',
                    isDark: isDark,
                  ),
                  const SizedBox(height: 10),
                  _SettingsCard(
                    cardBg: cardBg,
                    borderColor: borderColor,
                    children: [
                      // FIX: _onDarkModeChanged writes to themeModeNotifier
                      _ToggleTile(
                        icon: Icons.dark_mode_rounded,
                        iconColor: const Color(0xFF5C6BC0),
                        title: 'Dark Mode',
                        subtitle: 'Switch to dark theme',
                        value: _darkMode,
                        onChanged: _onDarkModeChanged,
                        isDark: isDark,
                      ),
                      _Divider(color: borderColor),
                      _ToggleTile(
                        icon: Icons.vibration_rounded,
                        iconColor: KavachColors.forest,
                        title: 'Haptic Feedback',
                        subtitle: 'Vibration on interactions',
                        value: _hapticFeedback,
                        onChanged: (v) {
                          setState(() => _hapticFeedback = v);
                          _savePref(_prefsHaptic, v);
                        },
                        isDark: isDark,
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // ── Permissions ──────────────────────────────────
                  _SectionHeader(
                    title: 'Permissions',
                    subtitle: 'अनुमतियाँ',
                    isDark: isDark,
                  ),
                  const SizedBox(height: 10),
                  _SettingsCard(
                    cardBg: cardBg,
                    borderColor: borderColor,
                    children: [
                      _ActionTile(
                        icon: Icons.security_rounded,
                        iconColor: KavachColors.crimson,
                        title: 'Manage Permissions',
                        subtitle: 'Microphone, location, SMS',
                        onTap: PermissionService.openSettings,
                        isDark: isDark,
                      ),
                      _Divider(color: borderColor),
                      _ActionTile(
                        icon: Icons.battery_saver_rounded,
                        iconColor: KavachColors.warning,
                        title: 'Battery Optimization',
                        subtitle: 'Disable for best performance',
                        onTap: () => _showBatteryGuide(context),
                        isDark: isDark,
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // ── About ────────────────────────────────────────
                  _SectionHeader(
                    title: 'About',
                    subtitle: 'ऐप के बारे में',
                    isDark: isDark,
                  ),
                  const SizedBox(height: 10),
                  _SettingsCard(
                    cardBg: cardBg,
                    borderColor: borderColor,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                gradient: KavachColors.saffronGradient,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: const Icon(
                                Icons.shield_rounded,
                                color: Colors.white,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Kavach',
                                    style: TextStyle(
                                      color: textColor,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  Text(
                                    'v2.0.0 — AI SOS Protection',
                                    style: TextStyle(
                                      color: subtextColor,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Sensitivity colour helpers ──────────────────────────────────
  Color get _sensitivityColor {
    if (_aiSensitivity > 0.8) return KavachColors.crimson;
    if (_aiSensitivity > 0.5) return KavachColors.saffron;
    return KavachColors.forest;
  }

  String get _sensitivityLabel {
    if (_aiSensitivity > 0.8) return 'HIGH';
    if (_aiSensitivity > 0.5) return 'MED';
    return 'LOW';
  }

  // ── Battery guide bottom sheet ──────────────────────────────────
  void _showBatteryGuide(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark
              ? KavachColors.darkSurface
              : KavachColors.cardLight,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: KavachColors.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Battery Optimization',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            const Text(
              'To ensure Kavach works in the background:',
              style: TextStyle(color: KavachColors.slate, fontSize: 13),
            ),
            const SizedBox(height: 16),
            const _StepItem(step: '1', text: 'Open phone Settings'),
            const _StepItem(
                step: '2', text: 'Go to Battery / Power Management'),
            const _StepItem(step: '3', text: 'Find "Kavach" in the app list'),
            const _StepItem(
              step: '4',
              text: 'Select "Unrestricted" or "No restrictions"',
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Got it'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Reusable sub-widgets ─────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title, subtitle;
  final bool isDark;
  const _SectionHeader({
    required this.title,
    required this.subtitle,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          title,
          style: TextStyle(
            color: isDark ? Colors.white : KavachColors.ink,
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          subtitle,
          style: TextStyle(
            color: isDark ? KavachColors.textOnDarkMuted : KavachColors.slate,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}

class _SettingsCard extends StatelessWidget {
  final Color cardBg, borderColor;
  final List<Widget> children;
  const _SettingsCard({
    required this.cardBg,
    required this.borderColor,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }
}

class _ToggleTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title, subtitle;
  final bool value, isDark;
  final ValueChanged<bool> onChanged;

  const _ToggleTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: isDark ? Colors.white : KavachColors.ink,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: isDark
                        ? KavachColors.textOnDarkMuted
                        : KavachColors.slate,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: value,
            onChanged: onChanged,
            activeColor: KavachColors.saffron,
          ),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title, subtitle;
  final VoidCallback onTap;
  final bool isDark;

  const _ActionTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: isDark ? Colors.white : KavachColors.ink,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: isDark
                          ? KavachColors.textOnDarkMuted
                          : KavachColors.slate,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: isDark ? KavachColors.textOnDarkMuted : KavachColors.slate,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  final Color color;
  const _Divider({required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(height: 1, color: color),
    );
  }
}

class _StepItem extends StatelessWidget {
  final String step, text;
  const _StepItem({required this.step, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: KavachColors.saffron.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                step,
                style: const TextStyle(
                  color: KavachColors.saffron,
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text, style: const TextStyle(fontSize: 13)),
          ),
        ],
      ),
    );
  }
}

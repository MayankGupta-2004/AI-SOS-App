import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'providers/kavach_providers.dart';
import 'services/ai_service.dart';
import 'services/contact_service.dart';
import 'services/language_service.dart';       // FIX 1 — was never imported
import 'services/notification_service.dart';
import 'services/permission_service.dart';
import 'screens/home_screen.dart';
import 'screens/splash_screen.dart';
import 'screens/language_screen.dart';
import 'theme/kavach_theme.dart';

// FIX 2 — global ValueNotifier so SettingsScreen can flip ThemeMode
// and MaterialApp reacts immediately without a full rebuild chain.
final themeModeNotifier = ValueNotifier<ThemeMode>(ThemeMode.system);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Lock to portrait — safety app should never rotate accidentally
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Step 1 — Permissions
  try {
    await PermissionService.requestAllPermissions();
  } catch (e) {
    debugPrint('[Main] Permission request failed: $e');
  }

  // Step 2 — Notifications
  try {
    await NotificationService().init();
  } catch (e) {
    debugPrint('[Main] Notification init failed: $e');
  }

  // Step 3 — AI models
  final aiService = AIService();
  try {
    await aiService.initModels();
  } catch (e) {
    debugPrint('[Main] AI model init failed: $e');
  }

  // Step 4 — Contacts
  final contactService = ContactService();
  try {
    await contactService.loadContacts();
  } catch (e) {
    debugPrint('[Main] Contact load failed: $e');
  }

  // Step 5 — FIX 1: LanguageService — was NEVER called before.
  // Without this, activeKeywords is always empty and keyword detection
  // ignores the user's language selection entirely.
  final languageService = LanguageService();
  try {
    await languageService.load();
    debugPrint('[Main] LanguageService loaded — activeKeywords: ${languageService.activeKeywords.length}');
  } catch (e) {
    debugPrint('[Main] LanguageService load failed: $e');
  }

  // Step 6 — Onboarding + saved theme
  bool onboarded = false;
  try {
    final prefs = await SharedPreferences.getInstance();
    onboarded = prefs.getBool('kavach_onboarded') ?? false;

    // FIX 2: restore saved theme preference
    final savedTheme = prefs.getString('kavach_theme') ?? 'system';
    themeModeNotifier.value = switch (savedTheme) {
      'dark'  => ThemeMode.dark,
      'light' => ThemeMode.light,
      _       => ThemeMode.system,
    };
  } catch (e) {
    debugPrint('[Main] Prefs read failed: $e');
  }

  runApp(
    ProviderScope(
      overrides: [
        aiServiceProvider.overrideWithValue(aiService),
        contactServiceProvider.overrideWithValue(contactService),
        languageServiceProvider.overrideWithValue(languageService), // FIX 1
      ],
      child: KavachApp(isOnboarded: onboarded),
    ),
  );
}

class KavachApp extends ConsumerWidget {
  final bool isOnboarded;
  const KavachApp({super.key, required this.isOnboarded});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final aiService      = ref.watch(aiServiceProvider);
    final contactService = ref.watch(contactServiceProvider);

    // FIX 2: ValueListenableBuilder makes MaterialApp react to theme changes
    // from SettingsScreen without needing setState anywhere up the tree.
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeModeNotifier,
      builder: (_, themeMode, __) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Kavach — AI SOS Protection',
        theme: KavachTheme.lightTheme,
        darkTheme: KavachTheme.darkTheme,
        themeMode: themeMode,            // FIX 2 — was hardcoded, never changed
        home: _AppEntry(
          aiService: aiService,
          contactService: contactService,
          isOnboarded: isOnboarded,
        ),
      ),
    );
  }
}

/// _AppEntry — Manages splash → onboarding → home flow
class _AppEntry extends StatefulWidget {
  final AIService aiService;
  final ContactService contactService;
  final bool isOnboarded;

  const _AppEntry({
    required this.aiService,
    required this.contactService,
    required this.isOnboarded,
  });

  @override
  State<_AppEntry> createState() => _AppEntryState();
}

class _AppEntryState extends State<_AppEntry> {
  late _AppScreen _currentScreen;

  @override
  void initState() {
    super.initState();
    _currentScreen = _AppScreen.splash;
  }

  void _onSplashComplete() {
    if (!mounted) return;
    setState(() {
      _currentScreen =
          widget.isOnboarded ? _AppScreen.home : _AppScreen.language;
    });
  }

  // FIX 1: callback now receives List<String> (2 language codes) not String
  void _onLanguageSelected(List<String> codes) {
    if (!mounted) return;
    setState(() => _currentScreen = _AppScreen.home);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 500),
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: child,
      ),
      child: _buildScreen(),
    );
  }

  Widget _buildScreen() {
    switch (_currentScreen) {
      case _AppScreen.splash:
        return SplashScreen(
          key: const ValueKey('splash'),
          onComplete: _onSplashComplete,
        );
      case _AppScreen.language:
        return LanguageScreen(
          key: const ValueKey('language'),
          onLanguageSelected: _onLanguageSelected, // now List<String>
        );
      case _AppScreen.home:
        return HomeScreen(
          key: const ValueKey('home'),
          aiService: widget.aiService,
          contactService: widget.contactService,
        );
    }
  }
}

enum _AppScreen { splash, language, home }
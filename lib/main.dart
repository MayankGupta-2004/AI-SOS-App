import 'package:flutter/material.dart';
import 'services/ai_service.dart';
import 'services/contact_service.dart';
import 'services/permission_service.dart';
import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ── STEP 1: Request all permissions FIRST ──────────────────────
  // Must happen before any service tries to use mic, location, SMS
  await PermissionService.requestAllPermissions();

  // ── STEP 2: Load AI models ──────────────────────────────────────
  final aiService = AIService();
  await aiService.initModels();

  // ── STEP 3: Load saved contacts ────────────────────────────────
  final contactService = ContactService();
  await contactService.loadContacts();

  runApp(MyApp(aiService: aiService, contactService: contactService));
}

class MyApp extends StatelessWidget {
  final AIService aiService;
  final ContactService contactService;

  const MyApp({
    super.key,
    required this.aiService,
    required this.contactService,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Kavach — AI SOS Protection',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFB71C1C),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: HomeScreen(
        aiService: aiService,
        contactService: contactService,
      ),
    );
  }
}

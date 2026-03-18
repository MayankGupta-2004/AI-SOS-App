import 'package:flutter/material.dart';
import 'services/ai_service.dart';
import 'services/contact_service.dart';
import 'services/notification_service.dart';
import 'services/permission_service.dart';
import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Step 1: Request all permissions
  await PermissionService.requestAllPermissions();

  // Step 2: Initialize notifications
  await NotificationService().init();

  // Step 3: Load AI models
  final aiService = AIService();
  await aiService.initModels();

  // Step 4: Load saved contacts
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

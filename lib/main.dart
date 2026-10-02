import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:genui/genui.dart';

import 'firebase_options.dart';
import 'gemini.dart';
import 'kitchen_page.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (kDebugMode) {
    // Print every A2UI message genui receives. Great for "what did Gemini send?"
    configureLogging(logCallback: (level, message) => debugPrint('genui $level: $message'));
  }
  if (!offlineDemo) {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  }
  runApp(const NaijaKitchenApp());
}

class NaijaKitchenApp extends StatelessWidget {
  const NaijaKitchenApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Naija Kitchen',
      debugShowCheckedModeBanner: false,
      theme: buildKitchenTheme(),
      home: const KitchenPage(),
    );
  }
}

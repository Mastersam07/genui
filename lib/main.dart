import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'firebase_options.dart';
import 'kitchen_page.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
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

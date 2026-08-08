import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:ly_homes/screens/wifi.dart';

import 'services/firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const HomeAutomationApp());
}

class HomeAutomationApp extends StatelessWidget {
  const HomeAutomationApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Home Automation',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color.fromARGB(255, 247, 0, 0),
          brightness: Brightness.dark,
        ),
      ),
      home: const WifiConfigPage(), 
    );
  }
}

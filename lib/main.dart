import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:ly_homes/screens/dashboard_screen.dart';
import 'theme/app_theme.dart';
import 'services/preview_repository.dart';
import 'services/display_preferences.dart';

import 'services/firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!const bool.fromEnvironment('PREVIEW')) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }
  runApp(HomeAutomationApp(preferences: await DisplayPreferences.load()));
}

class HomeAutomationApp extends StatefulWidget {
  const HomeAutomationApp({super.key, this.preferences});
  final DisplayPreferences? preferences;
  @override
  State<HomeAutomationApp> createState() => _HomeAutomationAppState();
}

class _HomeAutomationAppState extends State<HomeAutomationApp> {
  late final DisplayPreferences _preferences =
      widget.preferences ?? DisplayPreferences();
  late final PreviewRepository? _preview = const bool.fromEnvironment('PREVIEW')
      ? PreviewRepository()
      : null;
  @override
  void dispose() {
    _preview?.dispose();
    if (widget.preferences == null) _preferences.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _preferences,
      builder: (context, _) => MaterialApp(
        title: 'LY Homes',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.build(Brightness.light),
        darkTheme: AppTheme.build(Brightness.dark),
        themeMode: _preferences.dark ? ThemeMode.dark : ThemeMode.light,
        home: DashboardScreen(
          repository: _preview,
          preview: _preview != null,
          preferences: _preferences,
        ),
      ),
    );
  }
}

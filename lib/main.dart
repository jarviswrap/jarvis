import 'package:flutter/material.dart';
import 'pages/home_page.dart';
import 'package:jarvis/core/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const JarvisApp());
}

class JarvisApp extends StatelessWidget {
  const JarvisApp({super.key});

  @override
  Widget build(BuildContext context) {

    return MaterialApp(
      title: 'Jarvis · 智能工作助手',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      theme: AppTheme.dark(),
      home: const HomePage(),
    );
  }
}
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'screens/home_screen.dart';
import 'core/utils/app_text_styles.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 立即启动应用，插件将在 HomeScreen 中异步加载
  runApp(const ProviderScope(child: JarvisApp()));
}

class JarvisApp extends StatelessWidget {
  const JarvisApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'JARVIS - 智能助手',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.cyan,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        fontFamily: 'JetBrainsMono',
        
        // 使用统一的文本主题
        textTheme: const TextTheme(
          displayLarge: AppTextStyles.titlePage,
          displayMedium: AppTextStyles.cardTitle,
          displaySmall: AppTextStyles.sectionTitle,
          headlineLarge: AppTextStyles.cardTitle,
          headlineMedium: AppTextStyles.sectionTitle,
          headlineSmall: AppTextStyles.subtitle,
          titleLarge: AppTextStyles.sectionTitle,
          titleMedium: AppTextStyles.subtitle,
          titleSmall: AppTextStyles.bodyBold,
          bodyLarge: AppTextStyles.bodyNormal,
          bodyMedium: AppTextStyles.inputText,  // TextFormField 使用这个
          bodySmall: AppTextStyles.bodySmall,
          labelLarge: AppTextStyles.buttonNormal,
          labelMedium: AppTextStyles.buttonSmall,
          labelSmall: AppTextStyles.bodySmall,
        ),
        
        // 统一输入框装饰主题
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(),
          enabledBorder: OutlineInputBorder(
            borderSide: BorderSide(color: Colors.grey),
          ),
          focusedBorder: OutlineInputBorder(
            borderSide: BorderSide(color: Colors.cyan, width: 2),
          ),
          errorBorder: OutlineInputBorder(
            borderSide: BorderSide(color: Colors.red),
          ),
          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          labelStyle: AppTextStyles.inputLabel,
          hintStyle: AppTextStyles.inputHint,
          errorStyle: AppTextStyles.inputError,
          isDense: true,
        ),
        // 统一按钮主题
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            textStyle: AppTextStyles.buttonNormal,
            iconSize: 16,
          ),
        ),
        
        appBarTheme: AppBarTheme(
          foregroundColor: Colors.white,
          backgroundColor: Colors.cyan.shade700,
          titleTextStyle: AppTextStyles.withColor(AppTextStyles.cardTitle, Colors.white),
          actionsIconTheme: const IconThemeData(
            color: Colors.white,
          ),
          actionsPadding: const EdgeInsets.only(right: 8.0),
        ),
      ),
      home: const HomeScreen(),
    );
  }
}

import 'package:flutter/material.dart';
import 'screens/cubefore_assistant_screen.dart';

void main() {
  runApp(const CubeforeChatbotDemoApp());
}

class CubeforeChatbotDemoApp extends StatelessWidget {
  const CubeforeChatbotDemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CubeFore AI',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0F766E)),
        scaffoldBackgroundColor: const Color(0xFFF6FAF9),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0F766E),
          brightness: Brightness.dark,
        ),
      ),
      home: const CubeforeAssistantScreen(),
    );
  }
}

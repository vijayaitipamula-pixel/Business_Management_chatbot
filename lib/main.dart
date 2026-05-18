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
      title: 'Cubefore Chatbot Demo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
      ),
      home: const CubeforeAssistantScreen(),
    );
  }
}
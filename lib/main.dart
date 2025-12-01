import 'package:flutter/material.dart';
import 'pages/home_page.dart';

void main() {
  runApp(const MacWhisperApp());
}

class MacWhisperApp extends StatelessWidget {
  const MacWhisperApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MacWhisper',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF1E1E1E),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF007AFF),
          surface: Color(0xFF2D2D2D),
        ),
      ),
      home: Builder(
        builder: (context) {
          final size = MediaQuery.of(context).size;
          if (size.width < 1300) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              // Suggest minimum window size
            });
          }
          return const HomePage();
        },
      ),
    );
  }
}

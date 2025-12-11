import 'package:flutter/material.dart';
import 'pages/home_page.dart';
import 'services/theme_provider.dart';

void main() {
  runApp(const MacWhisperApp());
}

class MacWhisperApp extends StatefulWidget {
  const MacWhisperApp({super.key});

  // Static method to access theme provider from anywhere
  static ThemeProvider? of(BuildContext context) {
    return context
        .findAncestorStateOfType<_MacWhisperAppState>()
        ?.themeProvider;
  }

  @override
  State<MacWhisperApp> createState() => _MacWhisperAppState();
}

class _MacWhisperAppState extends State<MacWhisperApp> {
  final ThemeProvider themeProvider = ThemeProvider();

  @override
  void initState() {
    super.initState();
    themeProvider.addListener(() {
      setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MacWhisper',
      debugShowCheckedModeBanner: false,
      theme: themeProvider.theme.themeData,
      home: Builder(
        builder: (context) {
          final size = MediaQuery.of(context).size;
          if (size.width < 1300) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              // Suggest minimum window size
            });
          }
          return HomePage(key: ValueKey(themeProvider.isDark));
        },
      ),
    );
  }
}

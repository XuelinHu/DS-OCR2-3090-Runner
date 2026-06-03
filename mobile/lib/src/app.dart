import 'package:flutter/material.dart';

import 'features/ocr_home_page.dart';

class DsOcrApp extends StatelessWidget {
  const DsOcrApp({super.key});

  @override
  Widget build(BuildContext context) {
    const seed = Color(0xFF256D85);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'DS OCR',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: seed,
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF7F8FA),
        appBarTheme: const AppBarTheme(
          centerTitle: false,
          backgroundColor: Color(0xFFF7F8FA),
          surfaceTintColor: Colors.transparent,
        ),
      ),
      home: const OcrHomePage(),
    );
  }
}

import 'package:flutter/material.dart';

import 'features/dashboard/dashboard_screen.dart';

void main() {
  runApp(const HealthInsightsApp());
}

class HealthInsightsApp extends StatelessWidget {
  const HealthInsightsApp({super.key});

  @override
  Widget build(BuildContext context) {
    const seedColor = Color(0xFF176B58);

    return MaterialApp(
      title: 'Health Insights',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: seedColor,
          surface: const Color(0xFFF7F8F5),
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF7F8F5),
        cardTheme: const CardThemeData(
          color: Colors.white,
          elevation: 0,
          margin: EdgeInsets.zero,
        ),
      ),
      home: DashboardScreen(),
    );
  }
}

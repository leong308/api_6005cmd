import 'package:api_6005cmd/app/theme/app_theme.dart';
import 'package:api_6005cmd/features/navigation/view/shell_page.dart';
import 'package:flutter/material.dart';

class SmartTravelApp extends StatelessWidget {
  const SmartTravelApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Smart Travel Planner',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: const ShellPage(),
    );
  }
}

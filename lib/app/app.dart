import 'package:flutter/material.dart';

import '../core/services/app_services.dart';
import '../core/theme/app_theme.dart';
import '../features/menu/presentation/home_screen.dart';

class GridSparkApp extends StatelessWidget {
  const GridSparkApp({super.key, required this.services});

  final AppServices services;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: services.settings,
      builder: (context, _) => MaterialApp(
        title: 'GridSpark',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: services.settings.darkMode
            ? ThemeMode.dark
            : ThemeMode.light,
        home: HomeScreen(services: services),
      ),
    );
  }
}

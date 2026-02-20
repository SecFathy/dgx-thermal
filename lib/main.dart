import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'providers/connection_provider.dart';
import 'screens/connection_screen.dart';
import 'services/alert_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AlertService.initialize();
  runApp(
    ChangeNotifierProvider(
      create: (_) => ConnectionProvider(),
      child: const DgxThermalApp(),
    ),
  );
}

class DgxThermalApp extends StatelessWidget {
  const DgxThermalApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DGX Thermal',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: Colors.black,
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF0A84FF),
          surface: Color(0xFF1C1C1E),
        ),
        cupertinoOverrideTheme: const CupertinoThemeData(
          brightness: Brightness.dark,
          primaryColor: Color(0xFF0A84FF),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          elevation: 0,
          surfaceTintColor: Colors.transparent,
        ),
        popupMenuTheme: const PopupMenuThemeData(
          color: Color(0xFF1C1C1E),
          textStyle: TextStyle(color: Colors.white),
        ),
      ),
      home: const ConnectionScreen(),
    );
  }
}

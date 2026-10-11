import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/prestamo_provider.dart';
import 'screens/dashboard_screen.dart';
import 'theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ACobraApp());
}

class ACobraApp extends StatelessWidget {
  const ACobraApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => PrestamoProvider(),
      child: MaterialApp(
        title: 'ACobraSema',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.build(),
        home: const DashboardScreen(),
      ),
    );
  }
}
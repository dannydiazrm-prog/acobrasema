import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'providers/prestamo_provider.dart';
import 'screens/dashboard_screen.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('es', null);
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
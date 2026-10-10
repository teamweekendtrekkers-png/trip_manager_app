import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/settings_provider.dart';
import 'providers/trips_provider.dart';
import 'screens/trips_list_screen.dart';
import 'models/app_settings.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize settings
  final settingsProvider = SettingsProvider();
  await settingsProvider.init();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: settingsProvider),
        ChangeNotifierProxyProvider<SettingsProvider, TripsProvider>(
          create: (context) => TripsProvider(AppSettings()),
          update: (context, settings, previous) {
            previous?.updateSettings(settings.settings);
            return previous ?? TripsProvider(settings.settings);
          },
        ),
      ],
      child: const TripManagerApp(),
    ),
  );
}

class TripManagerApp extends StatelessWidget {
  const TripManagerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<SettingsProvider>(
      builder: (context, settings, _) {
        return MaterialApp(
          title: 'Trip Manager',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          scrollBehavior: const ManagerScrollBehavior(),
          themeMode: settings.settings.darkMode
              ? ThemeMode.dark
              : ThemeMode.light,
          home: const TripsListScreen(),
        );
      },
    );
  }
}

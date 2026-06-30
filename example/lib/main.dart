import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:adaptive_platform_ui_example/pages/demos/elys_tab_bar_platform_view/elys_tab_bar_comparison_page.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await LiquidGlassWidgets.initialize(enablePerformanceMonitor: false);
  runApp(LiquidGlassWidgets.wrap(child: const AdaptivePlatformUIDemo()));
}

class AdaptivePlatformUIDemo extends StatelessWidget {
  const AdaptivePlatformUIDemo({super.key});

  @override
  Widget build(BuildContext context) {
    return AdaptiveApp(
      themeMode: ThemeMode.system,
      title: 'Elys Tab Bar',
      home: const ElysTabBarComparisonPage(),
      cupertinoLightTheme: const CupertinoThemeData(
        brightness: Brightness.light,
      ),
      cupertinoDarkTheme: const CupertinoThemeData(brightness: Brightness.dark),
      materialLightTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        brightness: Brightness.light,
      ),
      materialDarkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        brightness: Brightness.dark,
      ),
      localizationsDelegates: [
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate, // Important!
        DefaultWidgetsLocalizations.delegate,
      ],
      locale: const Locale('en'),
      supportedLocales: [
        const Locale('en'), // English
        const Locale('tr'), // Turkish
        // ... other locales the app supports
      ],
    );
  }
}

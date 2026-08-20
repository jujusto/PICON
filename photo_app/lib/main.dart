import 'package:Picon/api_service.dart';
import 'package:Picon/home_screen.dart';
import 'package:Picon/login_screen.dart';
import 'package:Picon/screens/app_bootstrap_screen.dart';
import 'package:Picon/signup_screen.dart';
import 'package:Picon/utils/colors.dart';
import 'package:Picon/utils/police.dart';
import 'package:Picon/widgets/connectivity_wrapper.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:device_preview/device_preview.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  await ApiService.init();
  runApp(
    DevicePreview(
      enabled: false,
      builder: (context) => const MyApp(),
    ),
  );
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final _navigatorKey = GlobalKey<NavigatorState>();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      locale: DevicePreview.locale(context),
      builder: (context, child) {
        child = DevicePreview.appBuilder(context, child);
        return ConnectivityWrapper(child: child);
      },
      navigatorKey: _navigatorKey, // Add navigator key
      title: 'Photo App',
      theme: ThemeData(
        primarySwatch: AppColors.primarySwatch,
        primaryColor: AppColors.primary,
        colorScheme: ColorScheme.light(
          primary: AppColors.primary,
          onPrimary: AppColors.textOnPrimary,
          secondary: AppColors.accent,
          onSecondary: AppColors.textOnPrimary,
          surface: AppColors.card,
        ),
        scaffoldBackgroundColor: AppColors.background,
        textTheme: buildPoppinsTextTheme(ThemeData.light().textTheme),
        fontFamily: primaryFont.fontFamily,
      ),
      debugShowCheckedModeBanner: false,
      home: const AppBootstrapScreen(),
      onGenerateRoute: (settings) {
        switch (settings.name) {
          case '/login':
            return MaterialPageRoute(builder: (context) => const LoginScreen());
          case '/signup':
             return MaterialPageRoute(builder: (context) => const SignupScreen());
          case '/home':
            final args = settings.arguments as Map<String, dynamic>?;
            return MaterialPageRoute(
              builder: (context) => HomeScreen(
                userName: args?['userName'] as String? ?? 'Utilisateur',
                userLastName: args?['userLastName'] as String? ?? '',
                userEmail: args?['userEmail'] as String? ?? '',
                userId: args?['userId'] as int? ?? 0,
              ),
            );
          default:
            return MaterialPageRoute(builder: (context) => const LoginScreen());
        }
      },
    );
  }

}

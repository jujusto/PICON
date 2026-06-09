import 'package:Picon/api_service.dart';
import 'package:Picon/home_screen.dart';
import 'package:Picon/login_screen.dart';
import 'package:Picon/screens/permissions_onboarding_screen.dart';
import 'package:Picon/utils/app_permissions_service.dart';
import 'package:Picon/utils/colors.dart';
import 'package:flutter/material.dart';

/// Point d'entrée : permissions (1ère fois) puis login ou accueil.
class AppBootstrapScreen extends StatefulWidget {
  const AppBootstrapScreen({super.key});

  @override
  State<AppBootstrapScreen> createState() => _AppBootstrapScreenState();
}

class _AppBootstrapScreenState extends State<AppBootstrapScreen> {
  bool _loading = true;
  bool _showPermissionsOnboarding = false;

  @override
  void initState() {
    super.initState();
    _checkOnboarding();
  }

  Future<void> _checkOnboarding() async {
    final done = await AppPermissionsService.isOnboardingDone();
    if (!mounted) return;
    setState(() {
      _loading = false;
      _showPermissionsOnboarding = !done;
    });
  }

  void _onPermissionsComplete() {
    setState(() => _showPermissionsOnboarding = false);
  }

  Widget _destination() {
    if (ApiService.authToken != null && ApiService.userId != null) {
      return HomeScreen(
        userName: ApiService.userName ?? 'Utilisateur',
        userLastName: ApiService.userLastName ?? '',
        userEmail: ApiService.userEmail ?? '',
        userId: ApiService.userId!,
      );
    }
    return const LoginScreen();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_showPermissionsOnboarding) {
      return PermissionsOnboardingScreen(
        onComplete: _onPermissionsComplete,
      );
    }

    return _destination();
  }
}

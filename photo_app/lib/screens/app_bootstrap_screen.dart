import 'package:Picon/api_service.dart';
import 'package:Picon/home_screen.dart';
import 'package:Picon/login_screen.dart';
import 'package:Picon/screens/permissions_onboarding_screen.dart';
import 'package:Picon/utils/app_permissions_service.dart';
import 'package:Picon/utils/app_update_service.dart';
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
    _schedulePlayUpdateCheck();
  }

  void _onPermissionsComplete() {
    setState(() => _showPermissionsOnboarding = false);
    _schedulePlayUpdateCheck();
  }

  /// Après splash / bootstrap, pas pendant l’écran permissions.
  void _schedulePlayUpdateCheck() {
    // Une APK locale n’interroge jamais les services de diffusion Play.
    if (ApiService.isLocalTestBuild) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _loading || _showPermissionsOnboarding) return;
      AppUpdateService.instance.maybePrompt(context);
    });
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
    final localConfigurationError = ApiService.localTestConfigurationError;
    if (localConfigurationError != null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.lan_outlined,
                      size: 48, color: AppColors.primary),
                  const SizedBox(height: 16),
                  const Text(
                    'Configuration locale requise',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    localConfigurationError,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 15, height: 1.4),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

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

import 'package:Picon/utils/app_permissions_service.dart';
import 'package:Picon/utils/colors.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

/// Écran obligatoire au premier lancement : autorisations requises pour utiliser Picon.
class PermissionsOnboardingScreen extends StatefulWidget {
  final VoidCallback onComplete;

  const PermissionsOnboardingScreen({
    super.key,
    required this.onComplete,
  });

  @override
  State<PermissionsOnboardingScreen> createState() =>
      _PermissionsOnboardingScreenState();
}

class _PermissionsOnboardingScreenState extends State<PermissionsOnboardingScreen> {
  bool _isRequesting = false;
  String? _errorMessage;

  Future<void> _authorize() async {
    if (_isRequesting) return;
    setState(() {
      _isRequesting = true;
      _errorMessage = null;
    });

    final results = await AppPermissionsService.requestEssentialPermissions();
    final granted = AppPermissionsService.essentialGranted(results) ||
        await AppPermissionsService.areEssentialCurrentlyGranted();

    if (!mounted) return;

    if (!granted) {
      setState(() {
        _isRequesting = false;
        _errorMessage =
            'Ces autorisations sont obligatoires pour utiliser Picon. '
            'Activez-les dans les paramètres ou appuyez à nouveau sur le bouton.';
      });
      return;
    }

    await AppPermissionsService.markOnboardingDone();
    if (mounted) {
      setState(() => _isRequesting = false);
      widget.onComplete();
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 24),
                const Icon(Icons.security, size: 56, color: AppColors.primary),
                const SizedBox(height: 20),
                const Text(
                  'Autorisations requises',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Pour commander et payer vos tirages photo, Picon a besoin de ces accès. '
                  'Vous ne pourrez pas continuer sans les autoriser.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 32),
                const _PermissionTile(
                  icon: Icons.sim_card_outlined,
                  title: 'Téléphone',
                  subtitle:
                      'Détecter vos cartes SIM et lancer le paiement Mobile Money (Yas / Flooz) sur la bonne ligne.',
                ),
                const SizedBox(height: 16),
                const _PermissionTile(
                  icon: Icons.photo_library_outlined,
                  title: 'Photos',
                  subtitle:
                      'Choisir les images à imprimer depuis votre galerie.',
                ),
                if (_errorMessage != null) ...[
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFEBEE),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFE57373)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.error_outline,
                          color: Color(0xFFC62828),
                          size: 22,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFFC62828),
                              height: 1.35,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const Spacer(),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _isRequesting ? null : _authorize,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: _isRequesting
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Autoriser et continuer',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
                if (_errorMessage != null) ...[
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: OutlinedButton(
                      onPressed: _isRequesting ? null : openAppSettings,
                      child: const Text('Ouvrir les paramètres'),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PermissionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _PermissionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.12)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: AppColors.primary, size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

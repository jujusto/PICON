import 'dart:ui';
import 'package:Picon/api_service.dart';
import 'package:Picon/models/contact_info.dart';
import 'package:Picon/utils/colors.dart';
import 'package:Picon/utils/geometric_background.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:pinput/pinput.dart';
import 'package:country_code_picker/country_code_picker.dart';


class RecoveryScreen extends StatefulWidget {
  const RecoveryScreen({super.key});

  @override
  State<RecoveryScreen> createState() => _RecoveryScreenState();
}

class _RecoveryScreenState extends State<RecoveryScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController(); // Changed from _nameController
  final _phoneController = TextEditingController();
  final _pinController = TextEditingController();
  bool _isRecoveryWithEmail = true; // Changed from _isRecoveryWithName
  bool _isLoading = false;
  String _selectedDialCode = '+228';

  Future<void> _recoverPassword() async {
    if (_formKey.currentState?.validate() ?? false) {
      setState(() {
        _isLoading = true;
      });

      String identifier;
      if (_isRecoveryWithEmail) {
        identifier = _emailController.text.trim();
      } else {
        identifier = _buildFullPhoneNumber(_phoneController.text);
      }

      try {
        final response = await ApiService.verifyPinForPasswordReset(
          email: _isRecoveryWithEmail ? identifier : null,
          phone: !_isRecoveryWithEmail ? identifier : null,
          pin: _pinController.text,
        );

        if (mounted) {
          final resetToken = response['resetToken'];
          _showNewPasswordDialog(resetToken);
        }
        } catch (e) {
        if (mounted) {
          String errorMessage = e.toString();
          if (errorMessage.startsWith('Exception: ')) {
            errorMessage = errorMessage.substring(11);
          }
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(errorMessage), backgroundColor: Colors.red),
          );
        }
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  String _buildFullPhoneNumber(String rawPhone) {
    final cleaned = rawPhone.trim().replaceAll(RegExp(r'\s+'), '');
    if (cleaned.startsWith('+')) {
      return cleaned;
    }
    return '$_selectedDialCode$cleaned';
  }

  void _showNewPasswordDialog(String resetToken) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _NewPasswordDialog(resetToken: resetToken),
    );
  }

  void _showContactAdminPopup() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: FutureBuilder<ContactInfo>(
            future: ApiService.fetchContactInfo(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SizedBox(
                  height: 180,
                  child: Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  ),
                );
              }

              if (snapshot.hasError || !snapshot.hasData) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Contacter l\'administrateur',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'Impossible de charger les coordonnées depuis le serveur pour le moment.',
                      style: TextStyle(
                        fontSize: 16,
                        color: AppColors.textSecondary,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Fermer'),
                      ),
                    ),
                  ],
                );
              }

              final contactInfo = snapshot.data!;
              final phoneNumbers = _extractPhoneNumbers(contactInfo.phoneNumber);
              final email = contactInfo.email.trim();

              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Contacter l\'administrateur',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Pour réinitialiser votre code secret, contactez l\'administrateur :',
                    style: TextStyle(
                      fontSize: 16,
                      color: AppColors.textSecondary,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 14),
                  if (email.isNotEmpty)
                    _ContactActionTile(
                      icon: Icons.email_outlined,
                      title: 'Envoyer un email',
                      value: email,
                      onTap: () => _launchContactUri(
                        context: context,
                        uri: Uri(
                          scheme: 'mailto',
                          path: email,
                        ),
                      ),
                    ),
                  if (phoneNumbers.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    ...phoneNumbers.map(
                      (phone) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _ContactActionTile(
                          icon: Icons.phone_outlined,
                          title: 'Appeler',
                          value: phone,
                          onTap: () => _launchContactUri(
                            context: context,
                            uri: Uri(
                              scheme: 'tel',
                              path: phone.replaceAll(' ', ''),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Fermer'),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  List<String> _extractPhoneNumbers(String rawValue) {
    return rawValue
        .split(RegExp(r'[/,;\n]'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList();
  }

  Future<void> _launchContactUri({
    required BuildContext context,
    required Uri uri,
  }) async {
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Impossible d\'ouvrir ${uri.toString()}')),
      );
    }
  }

  @override
  void dispose() {
    _emailController.dispose(); // Changed from _nameController
    _phoneController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: CircleAvatar(
            backgroundColor: Colors.white,
            child: IconButton(
              icon: const Icon(Icons.arrow_back, color: AppColors.primary),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
        ),
      ),
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          GeometricBackground(),
          SafeArea(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  _buildHeader(),
                  _buildForm(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return SizedBox(
      height: 220,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 30),
          Image.asset(
            'assets/images/pro.png',
            height: 180, // Adjust height as needed
            width: 180, // Adjust width as needed
            fit: BoxFit.contain,
          ),
        ],
      ),
    );
  }

  Widget _buildForm() {
    final textTheme = Theme.of(context).textTheme;
    final defaultPinTheme = PinTheme(
      width: 45,
      height: 50,
      textStyle: const TextStyle(fontSize: 20, color: AppColors.textPrimary, fontWeight: FontWeight.w600),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.primary.withOpacity(0.5)),
        borderRadius: BorderRadius.circular(12),
      ),
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(24.0, 0, 24.0, 24.0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.all(24.0),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withOpacity(0.3)),
            ),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      'Récupération du compte',
                      textAlign: TextAlign.center,
                      style: textTheme.headlineSmall?.copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Entrez vos informations pour continuer',
                    textAlign: TextAlign.center,
                    style: textTheme.bodyMedium?.copyWith(color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 24),
                  _buildRecoveryMethodToggle(),
                  const SizedBox(height: 24),

                  if (_isRecoveryWithEmail)
                    TextFormField(
                      controller: _emailController,
                      decoration: _glassyInputDecoration('Email', icon: Icons.email_outlined),
                      textInputAction: TextInputAction.next,
                      keyboardType: TextInputType.emailAddress,
                      validator: (value) {
                        if (value == null || value.isEmpty) return 'Champ requis';
                        if (!RegExp(r"^[a-zA-Z0-9.]+@[a-zA-Z0-9]+\.[a-zA-Z]+").hasMatch(value)) return 'Email invalide';
                        return null;
                      },
                    )
                  else
                    TextFormField(
                      controller: _phoneController,
                      decoration: _glassyInputDecoration(
                        'Numéro de téléphone',
                        prefix: CountryCodePicker(
                          onChanged: (countryCode) {
                            setState(() {
                              _selectedDialCode = countryCode.dialCode ?? '+228';
                            });
                          },
                          initialSelection: 'TG',
                          favorite: const ['+228', '+225', '+223'],
                          countryFilter: const ['DZ', 'AO', 'BJ', 'BW', 'BF', 'BI', 'CM', 'CV', 'CF', 'TD', 'KM', 'CG', 'CD', 'CI', 'DJ', 'EG', 'GQ', 'ER', 'ET', 'GA', 'GM', 'GH', 'GN', 'GW', 'KE', 'LS', 'LR', 'LY', 'MG', 'MW', 'ML', 'MR', 'MU', 'YT', 'MA', 'MZ', 'NA', 'NE', 'NG', 'RE', 'RW', 'SH', 'ST', 'SN', 'SC', 'SL', 'SO', 'ZA', 'SS', 'SD', 'SZ', 'TZ', 'TG', 'TN', 'UG', 'EH', 'ZM', 'ZW'],
                          textStyle: TextStyle(color: AppColors.textPrimary.withOpacity(0.9)),
                        ),
                      ),
                      textInputAction: TextInputAction.next,
                      keyboardType: TextInputType.phone,
                      validator: (value) => (value?.isEmpty ?? true) ? 'Champ requis' : null,
                    ),

                  const SizedBox(height: 16),
                  Pinput(
                    controller: _pinController,
                    length: 4,
                    keyboardType: TextInputType.number,
                    defaultPinTheme: defaultPinTheme,
                    focusedPinTheme: defaultPinTheme.copyWith(
                      decoration: defaultPinTheme.decoration!.copyWith(border: Border.all(color: AppColors.primary)),
                    ),
                    validator: (s) => RegExp(r'^\d{4}$').hasMatch(s ?? '') ? null : 'Code secret invalide (4 chiffres)',
                  ),
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: _showContactAdminPopup,
                      child: const Text('Code secret oublié ?'),
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _recoverPassword, // Disable when loading
                    style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24))),
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('Valider', style: TextStyle(color: Colors.white, fontSize: 16)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRecoveryMethodToggle() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.1),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _isRecoveryWithEmail = true),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: _isRecoveryWithEmail ? AppColors.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Text(
                  'Email', // Changed from 'Nom'
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _isRecoveryWithEmail ? Colors.white : AppColors.textPrimary.withOpacity(0.7),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _isRecoveryWithEmail = false),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: !_isRecoveryWithEmail ? AppColors.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Text(
                  'Téléphone',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: !_isRecoveryWithEmail ? Colors.white : AppColors.textPrimary.withOpacity(0.7),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _glassyInputDecoration(String label, {IconData? icon, Widget? prefix}) {
    return InputDecoration(
      labelText: label,
      prefixIcon: prefix ?? (icon != null ? Icon(icon, color: AppColors.textPrimary.withOpacity(0.7)) : null),
      filled: true,
      fillColor: Colors.white.withOpacity(0.3),
      labelStyle: TextStyle(color: AppColors.textPrimary.withOpacity(0.7)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.grey.withOpacity(0.4)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.primary),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Colors.redAccent),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Colors.redAccent, width: 2),
      ),
    );
  }
}

class _NewPasswordDialog extends StatefulWidget {
  final String resetToken;

  const _NewPasswordDialog({required this.resetToken});

  @override
  State<_NewPasswordDialog> createState() => _NewPasswordDialogState();
}

class _ContactActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final VoidCallback onTap;

  const _ContactActionTile({
    required this.icon,
    required this.title,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.primary.withOpacity(0.06),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.16),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 20, color: AppColors.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      value,
                      style: const TextStyle(
                        fontSize: 16,
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_outward_rounded,
                size: 18,
                color: AppColors.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NewPasswordDialogState extends State<_NewPasswordDialog> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;

  Future<void> _resetPassword() async {
    if (_formKey.currentState?.validate() ?? false) {
       setState(() {
        _isLoading = true;
      });

      try {
        await ApiService.resetPasswordWithToken(
          token: widget.resetToken,
          newPassword: _passwordController.text,
        );

        if (mounted) {
          Navigator.of(context).pop(); // Dismiss dialog
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Mot de passe réinitialisé avec succès !'), backgroundColor: Colors.green),
          );
          Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erreur de réinitialisation: $e'), backgroundColor: Colors.red),
          );
        }
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withOpacity(0.3)),
            ),
            child: Form(
              key: _formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: const Text(
                        'Créer un nouveau mot de passe',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                      ),
                    ),
                    const SizedBox(height: 24),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      textInputAction: TextInputAction.next,
                      decoration: _glassyInputDecoration('Nouveau mot de passe').copyWith(
                        suffixIcon: IconButton(
                          icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility, color: AppColors.textPrimary.withOpacity(0.7)),
                          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) return 'Champ requis';
                        if (value.length < 8) return '8 caractères minimum';
                        if (!value.contains(RegExp(r'[A-Z]'))) return '1 majuscule minimum';
                        if (!value.contains(RegExp(r'[a-z]'))) return '1 minuscule minimum';
                        if (!value.contains(RegExp(r'[0-9]'))) return '1 chiffre minimum';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _confirmPasswordController,
                      obscureText: _obscureConfirmPassword,
                      decoration: _glassyInputDecoration('Confirmer le mot de passe').copyWith(
                        suffixIcon: IconButton(
                          icon: Icon(_obscureConfirmPassword ? Icons.visibility_off : Icons.visibility, color: AppColors.textPrimary.withOpacity(0.7)),
                          onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                        ),
                      ),
                      validator: (value) {
                        if (value != _passwordController.text) return 'Les mots de passe ne correspondent pas';
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _resetPassword,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Text('Valider', style: TextStyle(color: Colors.white, fontSize: 16)),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Annuler', style: TextStyle(color: AppColors.textPrimary)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _glassyInputDecoration(String label) {
     return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: Colors.white.withOpacity(0.3),
      labelStyle: TextStyle(color: AppColors.textPrimary.withOpacity(0.7)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.grey.withOpacity(0.4)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.primary),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Colors.redAccent),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Colors.redAccent, width: 2),
      ),
    );
  }
}

import 'dart:ui';
import 'package:Picon/api_service.dart';
import 'package:Picon/utils/colors.dart';
import 'package:Picon/utils/geometric_background.dart';
import 'package:Picon/widgets/loading_button.dart';
import 'package:country_code_picker/country_code_picker.dart';
import 'package:flutter/material.dart';
import 'package:pinput/pinput.dart';


class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;
  String _selectedDialCode = '+228';

  Future<void> _signup() async {
    if (_formKey.currentState?.validate() ?? false) {
      // Don't set loading state here, it will be handled in the PIN sheet
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return _PinCreationSheet(
            name: _nameController.text,
            email: _emailController.text,
            phone: _buildFullPhoneNumber(_phoneController.text),
            password: _passwordController.text,
          );
        },
      );
    }
  }

  String _buildFullPhoneNumber(String rawPhone) {
    var cleaned = rawPhone.trim().replaceAll(RegExp(r'[\s.\-()]'), '');
    if (cleaned.startsWith('+')) {
      return cleaned;
    }
    if (cleaned.startsWith('00')) {
      return '+${cleaned.substring(2)}';
    }
    if (cleaned.startsWith('228') && cleaned.length >= 11) {
      return '+$cleaned';
    }
    if (cleaned.startsWith('0') && cleaned.length == 9) {
      cleaned = cleaned.substring(1);
    }
    return '$_selectedDialCode$cleaned';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
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
    final size = MediaQuery.of(context).size;
    return SizedBox(
      height: size.height * 0.25,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 30),
          Flexible(
            child: Image.asset(
              'assets/images/pro.png',
              height: 180, // Nominally 180, Flexible scales it down if needed
              width: 180,
              fit: BoxFit.contain,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildForm() {
    final textTheme = Theme.of(context).textTheme;
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
                  Text(
                    'Créer un compte',
                    textAlign: TextAlign.center,
                    style: textTheme.headlineSmall?.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: _nameController,
                    textInputAction: TextInputAction.next,
                    decoration: _glassyInputDecoration('Nom complet',
                        icon: Icons.person_outline),
                    validator: (value) =>
                        (value?.isEmpty ?? true) ? 'Champ requis' : null,
                  ),
                  const SizedBox(height: 16),
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
                        countryFilter: const [
                          'DZ',
                          'AO',
                          'BJ',
                          'BW',
                          'BF',
                          'BI',
                          'CM',
                          'CV',
                          'CF',
                          'TD',
                          'KM',
                          'CG',
                          'CD',
                          'CI',
                          'DJ',
                          'EG',
                          'GQ',
                          'ER',
                          'ET',
                          'GA',
                          'GM',
                          'GH',
                          'GN',
                          'GW',
                          'KE',
                          'LS',
                          'LR',
                          'LY',
                          'MG',
                          'MW',
                          'ML',
                          'MR',
                          'MU',
                          'YT',
                          'MA',
                          'MZ',
                          'NA',
                          'NE',
                          'NG',
                          'RE',
                          'RW',
                          'SH',
                          'ST',
                          'SN',
                          'SC',
                          'SL',
                          'SO',
                          'ZA',
                          'SS',
                          'SD',
                          'SZ',
                          'TZ',
                          'TG',
                          'TN',
                          'UG',
                          'EH',
                          'ZM',
                          'ZW'
                        ],
                        textStyle: TextStyle(
                            color: AppColors.textPrimary.withOpacity(0.9)),
                        dialogTextStyle:
                            const TextStyle(color: AppColors.textPrimary),
                        searchStyle:
                            const TextStyle(color: AppColors.textPrimary),
                        dialogBackgroundColor: Colors.white.withOpacity(0.95),
                        flagWidth: 25,
                      ),
                    ),
                    textInputAction: TextInputAction.next,
                    keyboardType: TextInputType.phone,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Numéro de téléphone requis';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _emailController,
                    decoration: _glassyInputDecoration('Email',
                        icon: Icons.email_outlined),
                    textInputAction: TextInputAction.next,
                    keyboardType: TextInputType.emailAddress,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Email requis';
                      }
                      if (!RegExp(r"^[a-zA-Z0-9.]+@[a-zA-Z0-9]+\.[a-zA-Z]+")
                          .hasMatch(value)) {
                        return 'Veuillez entrer un email valide';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    decoration: _glassyInputDecoration('Mot de passe',
                            icon: Icons.lock_outline)
                        .copyWith(
                      suffixIcon: IconButton(
                        icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_off
                                : Icons.visibility,
                            color: AppColors.textPrimary.withOpacity(0.7)),
                        onPressed: () => setState(
                            () => _obscurePassword = !_obscurePassword),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty)
                        return 'Mot de passe requis';
                      if (value.length < 8)
                        return 'Le mot de passe doit contenir au moins 8 caractères';
                      if (!value.contains(RegExp(r'[A-Z]')))
                        return 'Inclure au moins une majuscule';
                      if (!value.contains(RegExp(r'[a-z]')))
                        return 'Inclure au moins une minuscule';
                      if (!value.contains(RegExp(r'[0-9]')))
                        return 'Inclure au moins un chiffre';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _confirmPasswordController,
                    obscureText: _obscureConfirmPassword,
                    decoration: _glassyInputDecoration(
                            'Confirmer le mot de passe',
                            icon: Icons.lock_outline)
                        .copyWith(
                      suffixIcon: IconButton(
                        icon: Icon(
                            _obscureConfirmPassword
                                ? Icons.visibility_off
                                : Icons.visibility,
                            color: AppColors.textPrimary.withOpacity(0.7)),
                        onPressed: () => setState(() =>
                            _obscureConfirmPassword = !_obscureConfirmPassword),
                      ),
                    ),
                    validator: (value) {
                      if (value != _passwordController.text)
                        return 'Les mots de passe ne correspondent pas';
                      return null;
                    },
                  ),
                  const SizedBox(height: 32),
                  LoadingButton(
                    onPressed: _signup,
                    text: 'S\'inscrire',
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text("J'ai un compte...",
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(color: AppColors.textPrimary)),
                        ),
                      ),
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: TextButton(
                            onPressed: () =>
                                Navigator.pushReplacementNamed(context, '/login'),
                            child: const Text('Acceder',
                                style: TextStyle(color: AppColors.primary)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _glassyInputDecoration(String label,
      {IconData? icon, Widget? prefix}) {
    return InputDecoration(
      labelText: label,
      prefixIcon: prefix ??
          (icon != null
              ? Icon(icon, color: AppColors.textPrimary.withOpacity(0.7))
              : null),
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

class _PinCreationSheet extends StatefulWidget {
  final String name;
  final String email;
  final String phone;
  final String password;

  const _PinCreationSheet({
    required this.name,
    required this.email,
    required this.phone,
    required this.password,
  });

  @override
  State<_PinCreationSheet> createState() => _PinCreationSheetState();
}

class _PinCreationSheetState extends State<_PinCreationSheet> {
  final _pinController = TextEditingController();
  final _pinFocusNode = FocusNode();
  bool _isLoading = false; // Add a loading state

  Future<void> _validatePin() async {
    if (!RegExp(r'^\d{4}$').hasMatch(_pinController.text)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez entrer un code secret à 4 chiffres.'), backgroundColor: Colors.orange),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await ApiService.signup(
        widget.name,
        widget.email,
        widget.phone,
        widget.password,
        _pinController.text,
      );

      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop(); // Dismiss sheet
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Compte créé avec succès ! Vous pouvez maintenant vous connecter.'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pushReplacementNamed('/login');
      }
    } catch (e) {
      if (mounted) {
        // Pop the dialog to show the error on the main screen's scaffold
        Navigator.of(context, rootNavigator: true).pop();
        
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

  @override
  void dispose() {
    _pinController.dispose();
    _pinFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white, // Solid white background
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
            child: SingleChildScrollView(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'Créez votre code secret',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Ce code sécurisera vos transactions et connexions futures.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Utilisez 4 chiffres uniquement.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 24),
                  Pinput(
                    length: 4,
                    controller: _pinController,
                    focusNode: _pinFocusNode,
                    keyboardType: TextInputType.number,
                    defaultPinTheme: PinTheme(
                      width: MediaQuery.of(context).size.width < 360 ? 40 : 56,
                      height: MediaQuery.of(context).size.width < 360 ? 40 : 56,
                      textStyle: const TextStyle(fontSize: 20, color: AppColors.textPrimary, fontWeight: FontWeight.w600),
                      decoration: BoxDecoration(
                        border: Border.all(color: AppColors.primary.withOpacity(0.5)),
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _validatePin,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 80),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24))
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('Valider', style: TextStyle(color: Colors.white, fontSize: 16)),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

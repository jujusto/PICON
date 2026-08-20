import 'dart:ui';

import 'package:Picon/api_service.dart';
import 'package:Picon/models/contact_info.dart';
import 'package:Picon/utils/colors.dart';
import 'package:Picon/utils/geometric_background.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class ContactScreen extends StatefulWidget {
  const ContactScreen({super.key});

  @override
  State<ContactScreen> createState() => _ContactScreenState();
}

class _ContactScreenState extends State<ContactScreen> {
  late Future<ContactInfo> _contactInfoFuture;

  @override
  void initState() {
    super.initState();
    _contactInfoFuture = ApiService.fetchContactInfo();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
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
        title: const Text(
          'Contactez-nous',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: AppColors.textPrimary,
      ),
      body: Stack(
        children: [
          GeometricBackground(),
          SafeArea(
            child: FutureBuilder<ContactInfo>(
              future: _contactInfoFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                      child:
                          CircularProgressIndicator(color: AppColors.primary));
                }
                // fetchContactInfo renvoie toujours un fallback local en cas d'erreur API.
                final contactInfo =
                    snapshot.data ?? ApiService.defaultContactInfo;
                return SingleChildScrollView(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 20),
                      if (snapshot.hasError)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Text(
                            'Coordonnées hors-ligne (serveur indisponible).',
                            style: TextStyle(
                              color: Colors.orange.shade800,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      _buildInfoCard(context, contactInfo),
                      const SizedBox(height: 30),
                      Text(
                        'Suivez-nous',
                        style: Theme.of(context)
                            .textTheme
                            .headlineSmall
                            ?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary),
                      ),
                      const SizedBox(height: 20),
                      _buildSocialRow(contactInfo),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(BuildContext context, ContactInfo info) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withOpacity(0.3)),
          ),
          child: Column(
            children: [
              _ContactInfoTile(
                icon: Icons.location_on_outlined,
                title: 'Notre Studio',
                subtitle: info.address,
                onTap: info.address.isNotEmpty
                    ? () => _launchUrl(
                        'https://maps.google.com/?q=${info.address}', context)
                    : null,
              ),
              const Divider(
                  height: 1, indent: 20, endIndent: 20, color: Colors.white30),
              _ContactInfoTile(
                icon: Icons.phone_outlined,
                title: 'Téléphone',
                subtitle: info.phoneNumber,
                onTap: info.phoneNumber.isNotEmpty
                    ? () => _launchUrl('tel:${info.phoneNumber}', context)
                    : null,
              ),
              const Divider(
                  height: 1, indent: 20, endIndent: 20, color: Colors.white30),
              _ContactInfoTile(
                icon: Icons.email_outlined,
                title: 'Email',
                subtitle: info.email,
                onTap: info.email.isNotEmpty
                    ? () => _launchUrl('mailto:${info.email}', context)
                    : null,
              ),
              const Divider(
                  height: 1, indent: 20, endIndent: 20, color: Colors.white30),
              _ContactInfoTile(
                icon: Icons.access_time,
                title: 'Horaires d\'ouverture',
                subtitle: info.openingHours,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSocialRow(ContactInfo info) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        if (info.facebookUrl != null && info.facebookUrl!.isNotEmpty)
          _SocialButton(
              icon: FontAwesomeIcons.facebook, url: info.facebookUrl!),
        if (info.twitterUrl != null && info.twitterUrl!.isNotEmpty)
          _SocialButton(icon: FontAwesomeIcons.twitter, url: info.twitterUrl!),
        if (info.instagramUrl != null && info.instagramUrl!.isNotEmpty)
          _SocialButton(
              icon: FontAwesomeIcons.instagram, url: info.instagramUrl!),
        if (info.linkedinUrl != null && info.linkedinUrl!.isNotEmpty)
          _SocialButton(
              icon: FontAwesomeIcons.linkedin, url: info.linkedinUrl!),
      ],
    );
  }

  Future<void> _launchUrl(String url, BuildContext context) async {
    final Uri uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Impossible d\'ouvrir $url')),
      );
    }
  }
}

class _ContactInfoTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  const _ContactInfoTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: Icon(icon, color: AppColors.primary, size: 30),
      title: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Text(
          title,
          style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: AppColors.textPrimary),
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
      ),
      trailing: onTap != null
          ? const Icon(Icons.arrow_forward_ios,
              size: 16, color: AppColors.textSecondary)
          : null,
    );
  }
}

class _SocialButton extends StatelessWidget {
  final IconData icon;
  final String url;

  const _SocialButton({required this.icon, required this.url});

  Future<void> _launchUrl(BuildContext context) async {
    final Uri uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Impossible d\'ouvrir $url')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: url,
      child: InkWell(
        onTap: () => _launchUrl(context),
        borderRadius: BorderRadius.circular(50),
        child: Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.primary.withOpacity(0.1),
          ),
          child: Center(
            child: FaIcon(icon, color: AppColors.primary, size: 28),
          ),
        ),
      ),
    );
  }
}

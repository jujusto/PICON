import 'dart:io';

import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Autorisations essentielles demandées une seule fois au premier lancement.
class AppPermissionsService {
  AppPermissionsService._();

  static const String _prefsKey = 'essential_permissions_onboarding_v1';

  static Future<bool> isOnboardingDone() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_prefsKey) ?? false;
  }

  static Future<void> markOnboardingDone() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefsKey, true);
  }

  /// Demande téléphone + photos en une passe (après explication à l'utilisateur).
  static Future<Map<Permission, PermissionStatus>> requestEssentialPermissions() async {
    final results = <Permission, PermissionStatus>{};

    if (Platform.isAndroid || Platform.isIOS) {
      results[Permission.phone] = await Permission.phone.request();
    }

    if (Platform.isAndroid || Platform.isIOS) {
      var photos = await Permission.photos.request();
      results[Permission.photos] = photos;
      if (Platform.isAndroid && !photos.isGranted) {
        final storage = await Permission.storage.request();
        results[Permission.storage] = storage;
      }
    }

    return results;
  }

  static bool essentialGranted(Map<Permission, PermissionStatus> results) {
    if (!Platform.isAndroid && !Platform.isIOS) return true;

    final phoneOk = !results.containsKey(Permission.phone) ||
        results[Permission.phone]!.isGranted;
    final photosOk = results[Permission.photos]?.isGranted == true ||
        results[Permission.storage]?.isGranted == true;

    return phoneOk && photosOk;
  }

  static Future<bool> areEssentialCurrentlyGranted() async {
    if (!Platform.isAndroid && !Platform.isIOS) return true;

    final phoneOk = await Permission.phone.isGranted;
    if (!phoneOk) return false;

    if (await Permission.photos.isGranted) return true;
    if (Platform.isAndroid && await Permission.storage.isGranted) {
      return true;
    }
    return false;
  }
}

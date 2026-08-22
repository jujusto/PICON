import 'package:Picon/api_service.dart';
import 'package:flutter/material.dart';

import 'main.dart' as productionApp;

/// Point d’entrée réservé aux APK de test local.
/// Le script build-local-apk.sh fournit obligatoirement PICON_LOCAL_TEST=true.
void main() {
  if (!ApiService.isLocalTestBuild) {
    runApp(const _LocalBuildConfigurationApp());
    return;
  }
  productionApp.main();
}

class _LocalBuildConfigurationApp extends StatelessWidget {
  const _LocalBuildConfigurationApp();

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Cette entrée est réservée à l’APK de test local. '
              'Utilisez scripts/build-local-apk.sh.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}

# Tests locaux PICON — backend, téléphone Android et APK debug

Ce dispositif est réservé aux essais locaux du correctif d’upload. Il ne modifie pas `main`, ne déploie rien et empêche la variante d’APK locale de contacter `api.photopicon.com`.

## 1. Préparer la machine

Installez Docker Desktop avec Docker Compose, Java 17 et Flutter avec le SDK Android API 36. Connectez le téléphone Android et l’ordinateur au même réseau Wi‑Fi. Relevez l’adresse IPv4 privée de l’ordinateur, par exemple `192.168.1.25`. N’utilisez ni `localhost` ni `127.0.0.1` dans l’APK : ces adresses désignent le téléphone lui-même.

Dans `photo_app_backend`, copiez le modèle local puis renseignez uniquement des secrets de développement :

```bash
cp .env.local.example .env.local
```

Mettez à jour `PICON_LOCAL_HOST_IP` avec l’IPv4 LAN de votre ordinateur et générez une clé JWT locale avec `openssl rand -hex 32`. Ne copiez jamais de secret de production dans ce fichier.

## 2. Démarrer le backend et la base de test

Toujours depuis `photo_app_backend`, démarrez uniquement la composition locale :

```bash
docker compose --env-file .env.local -f docker-compose.local.yml up --build
```

Le backend est alors disponible à `http://IP_LOCALE:8080`. La base de données est isolée dans le volume Docker `picon_local_mysql_data`, les photos de test sont stockées dans `photo_app_backend/local-uploads/` et les emails sont capturés localement dans Mailpit à `http://127.0.0.1:8025`.

Vérifiez depuis l’ordinateur :

```bash
curl http://127.0.0.1:8080/actuator/health
```

Si le téléphone ne peut pas joindre le backend, autorisez le port TCP `8080` dans le pare-feu de l’ordinateur et vérifiez qu’il est bien connecté au même Wi‑Fi. Arrêtez l’environnement avec `Ctrl+C`, ou effacez les données de test avec :

```bash
docker compose --env-file .env.local -f docker-compose.local.yml down -v
```

## 3. Construire l’APK locale

Depuis `photo_app`, rendez le script exécutable puis lancez-le avec l’adresse LAN du backend :

```bash
chmod +x scripts/build-local-apk.sh
./scripts/build-local-apk.sh http://192.168.1.25:8080/api
```

L’APK est produite dans `build/app/outputs/flutter-apk/picon-local-test.apk`. Elle porte l’identifiant Android `com.photopicon.app.local`, est signée avec la clé de debug et peut donc être installée à côté de l’application Play. Elle autorise HTTP uniquement dans la variante debug locale ; la release reste inchangée.

Les builds de diffusion futures doivent employer explicitement la saveur de production, par exemple `flutter build appbundle --flavor production --target lib/main.dart`. La saveur `local` est la seule à créer l’identifiant `.local` et à autoriser HTTP.

## 4. Vérifier le flux d’upload

Installez l’APK sur le téléphone, créez un compte de test, sélectionnez une ou plusieurs images puis observez l’aperçu immédiat. Coupez brièvement le Wi‑Fi ou les données mobiles pendant un envoi : la photo doit rester visible avec le bouton **Réessayer**. Réactivez le réseau et vérifiez que le même envoi est repris sans doublon.

Ne validez pas un paiement réel pendant ces tests. Lorsque les scénarios sont validés, conservez les résultats avant de préparer un commit, puis une piste interne Google Play séparée.

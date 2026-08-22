#!/usr/bin/env bash
set -euo pipefail

api_base_url="${1:-}"

if [[ -z "$api_base_url" ]]; then
  echo "Usage : $0 http://IP_LOCALE:8080/api" >&2
  exit 64
fi

if [[ "$api_base_url" == *"api.photopicon.com"* ]]; then
  echo "Refus : une APK locale ne peut jamais utiliser api.photopicon.com." >&2
  exit 65
fi

if [[ ! "$api_base_url" =~ ^http:// ]]; then
  echo "Utilisez une URL HTTP locale, par exemple http://192.168.1.25:8080/api." >&2
  exit 66
fi

flutter build apk --debug \
  --flavor local \
  --target lib/main_local.dart \
  --dart-define=PICON_LOCAL_TEST=true \
  --dart-define=API_BASE_URL="$api_base_url"

artifact="build/app/outputs/flutter-apk/app-debug.apk"
destination="build/app/outputs/flutter-apk/picon-local-test.apk"
cp "$artifact" "$destination"
echo "APK locale créée : $destination"

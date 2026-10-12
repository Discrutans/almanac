# Production App Links

Настройка открытия приложения по HTTPS-ссылкам вида `https://api.example.com/join/TOKEN`.

## 1. Сервер

В `server/.env`:

```env
ALMANAC_PUBLIC_ORIGIN=https://api.example.com
ALMANAC_ANDROID_PACKAGE=com.example.almanac
ALMANAC_ANDROID_SHA256_CERT=AA:BB:CC:...
ALMANAC_IOS_TEAM_ID=ABCDE12345
ALMANAC_IOS_BUNDLE_ID=com.example.almanac
```

Проверка:

```bash
curl https://api.example.com/.well-known/assetlinks.json
curl https://api.example.com/.well-known/apple-app-site-association
```

Сервер отдаёт paths: `/join/*`, `/book/*`, `/plan/*` (все ведут в session deep link).

## 2. Android

Скопируйте `android/gradle.properties.example` → `android/gradle.properties` (или добавьте строку):

```properties
ALMANAC_DEEP_LINK_HOST=api.example.com
```

`AndroidManifest.xml` уже содержит intent-filter с `android:autoVerify="true"` для:
- `https://HOST/join`
- `https://HOST/book`
- `https://HOST/plan`

**SHA-256:** release keystore fingerprint должен совпадать с `ALMANAC_ANDROID_SHA256_CERT`:

```bash
keytool -list -v -keystore your-release.jks -alias your-alias
```

Сборка release → установка → проверка:

```bash
adb shell pm get-app-links com.example.almanac
```

## 3. iOS

1. Откройте `ios/Runner/Runner.entitlements`
2. Замените `YOUR_DOMAIN` на `api.example.com`:

```xml
<string>applinks:api.example.com</string>
```

3. В Apple Developer → App ID → включите **Associated Domains**
4. Xcode → Signing & Capabilities → Associated Domains (должен совпадать с entitlements)
5. `ALMANAC_IOS_TEAM_ID` + bundle id на сервере должны совпадать с приложением

Проверка: открыть Safari → `https://api.example.com/join/test` → banner «Open in Almanac».

## 4. Custom scheme (fallback)

Без verified App Links работает:

```
almanac://join/TOKEN?server=https%3A%2F%2Fapi.example.com
```

На **Windows desktop** custom scheme может не открыть приложение — используйте «Войти по токену» в «Ссылки и API».

## 5. Flutter Server URL

В приложении задайте тот же origin, что и `ALMANAC_PUBLIC_ORIGIN`, или передайте при сборке:

```bash
flutter build apk --release --obfuscate --split-debug-info=build/debug-info --dart-define=SERVER_URL=https://api.example.com
```

`PUBLIC_ORIGIN` по умолчанию берётся из Server URL.

Flutter-приложение для ухода за растениями: распознавание по фото (AI), напоминания об уходе, синхронизация через Firebase.


<div align="center">
  <img width="426" height="902" alt="image" src="docs/screenshots/01.png" />
  <img width="471" height="960" alt="image" src="docs/screenshots/02.png" />
  <img width="534" height="1147" alt="image" src="docs/screenshots/03.png" />
  <img width="534" height="1161" alt="image" src="docs/screenshots/04.png" />
  <img width="503" height="1099" alt="image" src="docs/screenshots/05.png" />
  <img width="502" height="1062" alt="image" src="docs/screenshots/06.png" />
  <img width="636" height="1235" alt="image" src="docs/screenshots/07.png" />
  <img width="590" height="1218" alt="image" src="docs/screenshots/08.png" />
  <img width="674" height="989" alt="image" src="docs/screenshots/09.png" />
</div>

## Стек

- Flutter / Dart
- Firebase (Auth, Firestore, Storage, FCM)
- OpenRouter API (распознавание и оценка состояния растений)

## Настройка перед запуском

### 1. Firebase

```bash
# Скопируйте шаблоны и заполните из Firebase Console
copy lib\firebase_options.example.dart lib\firebase_options.dart
copy android\app\google-services.json.example android\app\google-services.json
copy ios\Runner\GoogleService-Info.plist.example ios\Runner\GoogleService-Info.plist
```

Или сгенерируйте конфиг через FlutterFire CLI:

```bash
dart pub global activate flutterfire_cli
flutterfire configure
```

### 2. OpenRouter API-ключ

Ключ **не хранится в репозитории**. Передайте его при запуске:

```bash
flutter run --dart-define=OPENROUTER_API_KEY=ваш_ключ
```

Для сборки release:

```bash
flutter build apk --dart-define=OPENROUTER_API_KEY=ваш_ключ
```

### 3. Зависимости

```bash
flutter pub get
```

## Запуск

```bash
flutter run --dart-define=OPENROUTER_API_KEY=ваш_ключ
```

## Примечание

Секреты (Firebase-конфиг и API-ключи) не включены в репозиторий.  
Для локального запуска скопируйте `.example`-файлы и передайте ключ OpenRouter через `--dart-define`.

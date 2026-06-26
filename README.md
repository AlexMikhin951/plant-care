Flutter-приложение для ухода за растениями: распознавание по фото (AI), напоминания об уходе, синхронизация через Firebase.
<img width="426" height="902" alt="image" src="https://github.com/user-attachments/assets/cb39c971-f828-4b4a-bdd4-e93a1bf01cb8" />
<img width="471" height="960" alt="image" src="https://github.com/user-attachments/assets/8bd49016-e945-4fee-8141-d05869ecd7fa" />
<img width="534" height="1147" alt="image" src="https://github.com/user-attachments/assets/f4d497f9-948a-4163-ba3e-322b28fe4d1d" />
<img width="534" height="1161" alt="image" src="https://github.com/user-attachments/assets/c018a86a-51c3-4a74-aab6-ed88bae7f1f7" />
<img width="503" height="1099" alt="image" src="https://github.com/user-attachments/assets/3b253ba7-a70e-4bde-ad9f-42de3313cf7d" />
<img width="502" height="1062" alt="image" src="https://github.com/user-attachments/assets/eb270804-ed5b-4b83-8e89-866bae126ff5" />
<img width="636" height="1235" alt="image" src="https://github.com/user-attachments/assets/520b0805-8722-46bc-b858-eff73a81ac2c" />
<img width="590" height="1218" alt="image" src="https://github.com/user-attachments/assets/2243693f-45c6-4871-926a-53bd1fdc1b8e" />
<img width="674" height="989" alt="image" src="https://github.com/user-attachments/assets/91ada9ae-9b4b-4eff-99cc-a72726dbe07a" />

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

class AppSecrets {
  static const openRouterApiKey = String.fromEnvironment('OPENROUTER_API_KEY');

  static String get openRouterApiKeyOrThrow {
    if (openRouterApiKey.isEmpty) {
      throw StateError(
        'OPENROUTER_API_KEY не задан. '
        'Запустите: flutter run --dart-define=OPENROUTER_API_KEY=ваш_ключ',
      );
    }
    return openRouterApiKey;
  }
}

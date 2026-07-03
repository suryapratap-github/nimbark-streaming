class AppConfig {
  static const apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://nimbark-backend-r1mo.onrender.com/api',
  );
}

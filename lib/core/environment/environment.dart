enum AppEnvironment { dev, test, prod }

/// Global environment configuration for JonkStore POS.
class Environment {
  static const String _apiBaseUrl = String.fromEnvironment('API_BASE_URL');
  static const String _appEnvironment = String.fromEnvironment(
    'APP_ENV',
    defaultValue: 'dev',
  );
  static AppEnvironment _environment = AppEnvironment.dev;

  static void init([AppEnvironment? env]) {
    _environment = env ?? _environmentFromBuildConfig();
  }

  static AppEnvironment _environmentFromBuildConfig() {
    switch (_appEnvironment.toLowerCase()) {
      case 'prod':
      case 'production':
        return AppEnvironment.prod;
      case 'test':
        return AppEnvironment.test;
      default:
        return AppEnvironment.dev;
    }
  }

  static AppEnvironment get current => _environment;

  static String get baseUrl {
    if (_apiBaseUrl.isNotEmpty) {
      return _apiBaseUrl.endsWith('/')
          ? _apiBaseUrl.substring(0, _apiBaseUrl.length - 1)
          : _apiBaseUrl;
    }
    switch (_environment) {
      case AppEnvironment.dev:
        return 'http://localhost:5000/api';
      case AppEnvironment.test:
        return 'http://localhost:5000/api';
      case AppEnvironment.prod:
        throw StateError(
          'API_BASE_URL must be supplied for a production build. '
          'Example: --dart-define=API_BASE_URL=https://your-api.onrender.com/api',
        );
    }
  }

  static bool get isDev => _environment == AppEnvironment.dev;
  static bool get isTest => _environment == AppEnvironment.test;
  static bool get isProd => _environment == AppEnvironment.prod;
}

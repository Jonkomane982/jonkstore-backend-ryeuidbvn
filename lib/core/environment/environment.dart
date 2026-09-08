enum AppEnvironment { dev, test, prod }

/// Global environment configuration for JonkStore POS.
class Environment {
  static const String _apiBaseUrl = String.fromEnvironment('API_BASE_URL');
  static const String _appEnvironment = String.fromEnvironment(
    'APP_ENV',
    defaultValue: 'dev',
  );
  
  static AppEnvironment _environment = _environmentFromBuildConfig();

  static void init([AppEnvironment? env]) {
    if (env != null) {
      _environment = env;
    }
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
    // If a URL was provided via dart-define, use it.
    if (_apiBaseUrl.isNotEmpty) {
      return _apiBaseUrl.endsWith('/')
          ? _apiBaseUrl.substring(0, _apiBaseUrl.length - 1)
          : _apiBaseUrl;
    }

    // Fallbacks based on environment
    switch (_environment) {
      case AppEnvironment.prod:
        // Default production URL if none provided via dart-define
        return 'https://jonkstore-api-vwsh.onrender.com/api';
      case AppEnvironment.test:
      case AppEnvironment.dev:
      default:
        return 'http://localhost:5000/api';
    }
  }

  static bool get isDev => _environment == AppEnvironment.dev;
  static bool get isTest => _environment == AppEnvironment.test;
  static bool get isProd => _environment == AppEnvironment.prod;
}

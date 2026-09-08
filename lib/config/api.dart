import '../core/environment/environment.dart';

/// API configuration and header management.
class ApiConfig {
  /// The base URL for the API. 
  /// In production, this points to the Render deployment.
  static String get baseUrl {
    if (Environment.isProd) {
      return 'https://jonkstore-api-vwsh.onrender.com';
    }
    return Environment.baseUrl;
  }
}

/// Base exception class for the application.
class AppException implements Exception {
  final String message;
  final String? code;

  AppException(this.message, [this.code]);

  @override
  String toString() => 'AppException: [$code] $message';
}

/// Thrown when a network request fails.
class NetworkException extends AppException {
  NetworkException([super.message = 'No internet connection', super.code]);
}

/// Thrown when the server returns an error response.
class ServerException extends AppException {
  ServerException([super.message = 'Internal server error', super.code]);
}

/// Thrown when an error occurs during local database operations.
class DatabaseException extends AppException {
  DatabaseException([super.message = 'Database error', super.code]);
}

/// Thrown when authentication fails.
class AuthException extends AppException {
  AuthException([super.message = 'Authentication failed', super.code]);
}

/// Thrown when user input validation fails.
class ValidationException extends AppException {
  ValidationException([super.message = 'Validation failed', super.code]);
}

/// Thrown when cache operations fail.
class CacheException extends AppException {
  CacheException([super.message = 'Cache error', super.code]);
}

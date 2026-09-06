/// Base failure class for the application.
abstract class Failure {
  final String message;
  final String? code;

  const Failure(this.message, [this.code]);

  @override
  String toString() => 'Failure: [$code] $message';
}

/// Represents a failure due to network issues.
class NetworkFailure extends Failure {
  const NetworkFailure([super.message = 'No internet connection', super.code]);
}

/// Represents a failure returned by the server.
class ServerFailure extends Failure {
  const ServerFailure([super.message = 'Server error occurred', super.code]);
}

/// Represents a failure during database operations.
class DatabaseFailure extends Failure {
  const DatabaseFailure([super.message = 'Database error occurred', super.code]);
}

/// Represents a failure during authentication.
class AuthFailure extends Failure {
  const AuthFailure([super.message = 'Authentication failed', super.code]);
}

/// Represents a failure due to invalid user input.
class ValidationFailure extends Failure {
  const ValidationFailure([super.message = 'Invalid input', super.code]);
}

/// Represents an unknown failure.
class UnexpectedFailure extends Failure {
  const UnexpectedFailure([super.message = 'An unexpected error occurred', super.code]);
}

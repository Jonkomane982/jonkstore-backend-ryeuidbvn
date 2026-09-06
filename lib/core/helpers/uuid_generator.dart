import 'package:uuid/uuid.dart';

/// Utility to generate unique identifiers for the application.
class UuidGenerator {
  static const Uuid _uuid = Uuid();

  /// Generates a v4 (random) UUID.
  static String generate() => _uuid.v4();
}

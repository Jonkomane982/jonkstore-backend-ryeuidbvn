/// Environment configuration (Dev, Prod, Staging).
enum Environment { dev, prod, staging }

class AppEnvironment {
  static Environment current = Environment.dev;
}

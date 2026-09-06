import 'db_initializer_stub.dart'
    if (dart.library.io) 'db_initializer_native.dart'
    if (dart.library.js) 'db_initializer_web.dart'
    if (dart.library.js_interop) 'db_initializer_web.dart'
    if (dart.library.html) 'db_initializer_web.dart';

export 'db_initializer_base.dart';
import 'db_initializer_base.dart';

/// Factory method to get the correct initializer based on the platform.
/// Optimized for modern Flutter Web (WASM & JS).
DbInitializer getDbInitializer() => getPlatformDbInitializer();

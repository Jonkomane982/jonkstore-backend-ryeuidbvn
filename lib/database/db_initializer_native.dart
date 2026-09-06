import 'dart:io';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'db_initializer_base.dart';

class NativeDbInitializer implements DbInitializer {
  @override
  Future<DatabaseFactory> init() async {
    if (Platform.isWindows || Platform.isLinux) {
      // Initialize FFI for desktop platforms
      sqfliteFfiInit();
      return databaseFactoryFfi;
    }
    
    // On Android/iOS, use the default sqflite factory
    return databaseFactory;
  }
}

/// Overrides the stub implementation for native environments
DbInitializer getPlatformDbInitializer() => NativeDbInitializer();

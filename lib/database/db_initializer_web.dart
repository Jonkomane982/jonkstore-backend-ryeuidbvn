import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:sqflite/sqflite.dart';
import 'db_initializer_base.dart';
import 'in_memory_web_database.dart';

class WebDbInitializer implements DbInitializer {
  @override
  Future<DatabaseFactory> init() async {
    if (kDebugMode) {
      print(
        'JonkStore: [Web] Using InMemoryWebDatabaseFactory (persists via SharedPreferences).\n'
        '           sqflite_common_ffi_web driver is bypassed because its SQLite3 WASM\n'
        '           build throws "unsupported result null (null)" during openDatabase().',
      );
    }
    return InMemoryWebDatabaseFactory();
  }
}

DbInitializer getPlatformDbInitializer() => WebDbInitializer();

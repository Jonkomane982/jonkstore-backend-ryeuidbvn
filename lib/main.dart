import 'package:flutter/foundation.dart'
    show kDebugMode, kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'app/app.dart';
import 'core/environment/environment.dart';
import 'database/db_initializer.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  appDatabaseFactory = await getDbInitializer().init();

  final isDesktop =
      defaultTargetPlatform == TargetPlatform.windows ||
      defaultTargetPlatform == TargetPlatform.macOS ||
      defaultTargetPlatform == TargetPlatform.linux;

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    if (kDebugMode) {
      print(
        'JonkStore: Firebase initialized successfully'
        ' [${kIsWeb ? 'Web' : defaultTargetPlatform.name}]',
      );
    }
  } catch (e, stack) {
    if (kDebugMode) {
      print(
        'JonkStore: WARNING — Firebase init failed:'
        ' $e',
      );
      print(stack);
      if (isDesktop) {
        print(
          'JonkStore: Desktop build detected. Local features'
          ' (SQLite, UI) will still work. Auth features require valid'
          ' FirebaseOptions or network access.',
        );
      }
    }
  }

  Environment.init();

  runApp(const ProviderScope(child: JonkStoreApp()));
}

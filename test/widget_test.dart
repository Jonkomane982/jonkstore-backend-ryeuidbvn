import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jonkstore/app/app.dart';
import 'package:jonkstore/core/environment/environment.dart';

void main() {
  testWidgets('JonkStoreApp smoke test', (WidgetTester tester) async {
    Environment.init(AppEnvironment.dev);
    await tester.pumpWidget(
      const ProviderScope(
        child: JonkStoreApp(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}

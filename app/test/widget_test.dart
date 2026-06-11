import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:lumen/main.dart';
import 'package:lumen/screens/onboarding_screen.dart';
import 'package:lumen/services/db.dart';
import 'package:lumen/state/app_state.dart';

void main() {
  testWidgets('app shows a loading state before the database is ready',
      (tester) async {
    final state = AppState(LumenDb()); // not loaded — no platform DB in tests
    await tester.pumpWidget(LumenApp(state: state));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('onboarding screen renders both entry paths', (tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => AppState(LumenDb()),
        child: const MaterialApp(home: OnboardingScreen()),
      ),
    );
    expect(find.text('Lumen'), findsOneWidget);
    expect(find.text('Explore with demo data'), findsOneWidget);
    expect(find.text('Start fresh'), findsOneWidget);
  });
}

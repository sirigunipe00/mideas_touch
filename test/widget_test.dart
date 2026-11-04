import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mideas_touch/app/app.dart';
import 'package:mideas_touch/ui/overlays/overlays.dart';
import 'package:mideas_touch/ui/screens/home_screen.dart';
import 'package:mideas_touch/ui/screens/my_designs_screen.dart';
import 'package:mideas_touch/ui/screens/profile_screen.dart';
import 'package:mideas_touch/ui/screens/search_screen.dart';

import 'fakes.dart';

Future<FakeBackend> _boot(WidgetTester t, {FakeBackend? backend}) async {
  final b = backend ?? FakeBackend();
  t.view.physicalSize = const Size(430 * 2, 900 * 2);
  t.view.devicePixelRatio = 2;
  addTearDown(t.view.reset);
  await t.pumpWidget(MideaTouchApp(
    catalogRepository: b.catalogRepo,
    authRepository: b.authRepo,
    userRepository: b.userRepo,
  ));
  return b;
}

/// Dismisses the splash and lets the intro card finish sliding in.
Future<void> _toIntro(WidgetTester t) async {
  await t.pump(const Duration(seconds: 4));
  await _settle(t);
}

/// Lets a screen / sheet transition finish (the app has endless animations,
/// so `pumpAndSettle` cannot be used).
Future<void> _settle(WidgetTester t) async {
  await t.pump();
  await t.pump(const Duration(milliseconds: 700));
}

Future<void> _startExploring(WidgetTester t) async {
  await _toIntro(t);
  await t.tap(find.text('Start exploring'));
  await _settle(t);
}

void main() {
  testWidgets('splash, intro, then the home screen with database data', (t) async {
    await _boot(t);
    expect(find.byType(SplashOverlay), findsOneWidget);

    await _toIntro(t);
    expect(find.byType(SplashOverlay), findsNothing);
    expect(find.text('Welcome to Midas\'s Touch'), findsOneWidget);

    await t.tap(find.text('Start exploring'));
    await _settle(t);
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.text('Popular Designs'), findsOneWidget);
    // everything below comes from the (fake) database
    expect(find.text('Diwali Greeting 01'), findsWidgets);
    expect(find.text('Create beautiful promotional images in minutes'),
        findsWidgets);
    expect(find.text('Festivals'), findsWidgets);
  });

  testWidgets('a failed catalogue load can be retried', (t) async {
    final backend = FakeBackend()
      ..failCatalog = 'Network error. Check your connection and try again.';
    await _boot(t, backend: backend);
    await _startExploring(t);
    expect(find.text('Try again'), findsOneWidget);
    expect(find.text('Diwali Greeting 01'), findsNothing);

    backend.failCatalog = null;
    await t.tap(find.text('Try again'));
    await _settle(t);
    expect(find.text('Try again'), findsNothing);
    expect(find.text('Diwali Greeting 01'), findsWidgets);
  });

  testWidgets('bottom tabs switch screens', (t) async {
    await _boot(t);
    await _startExploring(t);

    await t.tap(find.text('Search'));
    await _settle(t);
    expect(find.byType(SearchScreen), findsOneWidget);

    await t.tap(find.text('My Designs'));
    await _settle(t);
    expect(find.byType(MyDesignsScreen), findsOneWidget);

    await t.tap(find.text('Profile'));
    await _settle(t);
    expect(find.byType(ProfileScreen), findsOneWidget);
  });

  testWidgets('customising registers a real account, then asks for coins', (t) async {
    final backend = await _boot(t);
    await _startExploring(t);

    await t.tap(find.text('Start Creating').last);
    await _settle(t);
    expect(find.text('Create your account'), findsOneWidget);

    final fields = find.byType(TextField);
    await t.enterText(fields.at(0), 'Tayyab');
    await t.enterText(fields.at(1), 'tayyab@example.com');
    await t.enterText(fields.at(2), 'password1');
    await t.tap(find.text('Create Account'));
    await _settle(t);

    expect(backend.signUps, 1);
    expect(backend.accounts['tayyab@example.com']!.name, 'Tayyab');
    expect(find.text('Get coins'), findsOneWidget);
    await t.pump(const Duration(seconds: 3));
  });

  testWidgets('a short password never reaches the backend', (t) async {
    final backend = await _boot(t);
    await _startExploring(t);

    await t.tap(find.text('Start Creating').last);
    await _settle(t);
    final fields = find.byType(TextField);
    await t.enterText(fields.at(1), 'tayyab@example.com');
    await t.enterText(fields.at(2), 'short');
    await t.tap(find.text('Create Account'));
    await _settle(t);

    expect(backend.signUps, 0);
    expect(find.text('Password must be at least 8 characters'), findsOneWidget);
    await t.pump(const Duration(seconds: 3));
  });
}

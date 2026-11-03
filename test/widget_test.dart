import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mideas_touch/app/app.dart';
import 'package:mideas_touch/ui/overlays/overlays.dart';
import 'package:mideas_touch/ui/screens/home_screen.dart';
import 'package:mideas_touch/ui/screens/my_designs_screen.dart';
import 'package:mideas_touch/ui/screens/profile_screen.dart';
import 'package:mideas_touch/ui/screens/search_screen.dart';

Future<void> _boot(WidgetTester t) async {
  t.view.physicalSize = const Size(430 * 2, 900 * 2);
  t.view.devicePixelRatio = 2;
  addTearDown(t.view.reset);
  await t.pumpWidget(const MideaTouchApp());
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

void main() {
  testWidgets('splash, intro, then the home screen', (t) async {
    await _boot(t);
    expect(find.byType(SplashOverlay), findsOneWidget);

    await _toIntro(t);
    expect(find.byType(SplashOverlay), findsNothing);
      expect(find.text('Welcome to Midas\'s Touch'), findsOneWidget);

    await t.tap(find.text('Start exploring'));
    await _settle(t);
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.text('Popular Designs'), findsOneWidget);
    expect(find.text('Diwali Sale'), findsWidgets);
  }); 

  testWidgets('bottom tabs switch screens', (t) async {
    await _boot(t);
    await _toIntro(t);
    await t.tap(find.text('Start exploring'));
    await _settle(t);

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

  testWidgets('customising asks to register, then to get coins', (t) async {
    await _boot(t);
    await _toIntro(t);
    await t.tap(find.text('Start exploring'));
    await _settle(t);

    await t.tap(find.text('Start Creating').last);
    await _settle(t);
    expect(find.text('Create your account'), findsOneWidget);

    await t.tap(find.text('Create Account'));
    await _settle(t);
    expect(find.text('Get coins'), findsOneWidget);
    await t.pump(const Duration(seconds: 3));
  });
}

import 'package:flutter/material.dart';
import '../core/theme/palette.dart';

const String kFontFamily = 'Poppins';
const List<String> kFontFallback = ['Noto Sans Devanagari', 'Hind'];

/// Builds the Material theme carrying the artifact's colour tokens.
ThemeData buildTheme(Brightness brightness) {
  final pal = brightness == Brightness.dark ? Pal.dark : Pal.light;
  final base = ThemeData(
    useMaterial3: false,
    brightness: brightness,
    fontFamily: kFontFamily,
  );
  final text = base.textTheme
      .apply(
        fontFamily: kFontFamily,
        fontFamilyFallback: kFontFallback,
        bodyColor: pal.tx,
        displayColor: pal.tx,
      )
      .copyWith(
        bodyMedium: TextStyle(
          fontFamily: kFontFamily,
          fontFamilyFallback: kFontFallback,
          fontSize: 14,
          height: 1.45,
          color: pal.tx,
          leadingDistribution: TextLeadingDistribution.even,
        ),
      );
  return base.copyWith(
    scaffoldBackgroundColor: pal.bd,
    canvasColor: pal.c,
    cardColor: pal.c,
    dividerColor: pal.ln,
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
    hoverColor: Colors.transparent,
    textTheme: text,
    primaryTextTheme: text,
    colorScheme: base.colorScheme.copyWith(
      primary: pal.p,
      onPrimary: pal.pt,
      secondary: pal.p,
      surface: pal.c,
      onSurface: pal.tx,
    ),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: pal.tx,
      selectionColor: pal.p.withOpacity(.35),
      selectionHandleColor: pal.p,
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: pal.c,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    extensions: [pal],
  );
}

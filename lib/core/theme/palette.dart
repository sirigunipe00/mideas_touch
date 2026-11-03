import 'package:flutter/material.dart';

/// Colour tokens lifted 1:1 from the artifact's CSS custom properties
/// (`--bg`, `--c`, `--tx`, `--mu`, `--p`, `--pt`, `--pd`, `--pl`, `--pl2`,
/// `--ln`, `--sh`, `--bd`) for both the light and the dark theme.
@immutable
class Pal extends ThemeExtension<Pal> {
  const Pal({
    required this.bg,
    required this.c,
    required this.tx,
    required this.mu,
    required this.p,
    required this.pt,
    required this.pd,
    required this.pl,
    required this.pl2,
    required this.ln,
    required this.bd,
    required this.sh,
  });

  /// App background.
  final Color bg;

  /// Card / surface colour.
  final Color c;

  /// Primary text.
  final Color tx;

  /// Muted text.
  final Color mu;

  /// Brand gold.
  final Color p;

  /// Text on gold.
  final Color pt;

  /// Dark gold (accent text).
  final Color pd;

  /// Light gold.
  final Color pl;

  /// Lighter gold, second tone.
  final Color pl2;

  /// Border / divider.
  final Color ln;

  /// Colour outside the "phone" (page background).
  final Color bd;

  /// Card shadow (`--sh`).
  final List<BoxShadow> sh;

  static const light = Pal(
    bg: Color(0xFFFFFDF6),
    c: Color(0xFFFFFFFF),
    tx: Color(0xFF2A2410),
    mu: Color(0xFF7A7255),
    p: Color(0xFFEFBF05),
    pt: Color(0xFF1D1700),
    pd: Color(0xFF8A6A00),
    pl: Color(0xFFFCF4D3),
    pl2: Color(0xFFFAEAAC),
    ln: Color(0xFFF1E6B8),
    bd: Color(0xFFE9E2C8),
    sh: [
      BoxShadow(
          color: Color.fromRGBO(138, 106, 0, .14),
          blurRadius: 16,
          offset: Offset(0, 4)),
    ],
  );

  static const dark = Pal(
    bg: Color(0xFF15130B),
    c: Color(0xFF211E11),
    tx: Color(0xFFF7F1D6),
    mu: Color(0xFFB3AA84),
    p: Color(0xFFEFBF05),
    pt: Color(0xFF1D1700),
    pd: Color(0xFFF6DA6F),
    pl: Color(0xFF33290A),
    pl2: Color(0xFF4A3C0C),
    ln: Color(0xFF3A3413),
    bd: Color(0xFF0C0A04),
    sh: [
      BoxShadow(
          color: Color.fromRGBO(0, 0, 0, .45),
          blurRadius: 16,
          offset: Offset(0, 4)),
    ],
  );

  @override
  Pal copyWith() => this;

  @override
  Pal lerp(ThemeExtension<Pal>? other, double t) {
    if (other is! Pal) return this;
    return t < .5 ? this : other;
  }
}

extension PalContext on BuildContext {
  Pal get pal => Theme.of(this).extension<Pal>()!;
  bool get isDark => Theme.of(this).brightness == Brightness.dark;
}

/// Fixed colours used by the artifact regardless of theme.
class Brand {
  static const gold = Color(0xFFEFBF05);
  static const goldSoft = Color(0xFFF6DA6F);
  static const ink = Color(0xFF1D1700);
  static const cream = Color(0xFFFCF4D3);
  static const red = Color(0xFFED0707);
  static const green = Color(0xFF15803D);
  static const freeGreen = Color(0xFF1EED07);
  static const freeGreenInk = Color(0xFF0B3300);
  static const toastBg = Color(0xFF2A2410);
}

import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../app/app_controller.dart';
import '../../core/theme/palette.dart';
import '../../state/nav_cubit.dart';
import '../widgets/coin.dart';

/// Seconds elapsed since mount, used to drive the CSS-style animations.
mixin _Clock<T extends StatefulWidget> on State<T>, SingleTickerProviderStateMixin<T> {
  late final AnimationController clock = AnimationController(
      vsync: this, duration: const Duration(seconds: 3600))
    ..forward();

  double get seconds => clock.value * 3600;

  @override
  void dispose() {
    clock.dispose();
    super.dispose();
  }
}

/// Dark cinematic splash: black field, gold dust, metallic brand mark.
class SplashOverlay extends StatefulWidget {
  const SplashOverlay({super.key});

  @override
  State<SplashOverlay> createState() => _SplashOverlayState();
}

class _SplashOverlayState extends State<SplashOverlay> {
  static const _bg = Color(0xFF000000);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: context.read<NavCubit>().dismissSplash,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 450),
        builder: (context, v, child) => Opacity(opacity: v, child: child),
        child: const ColoredBox(
          color: _bg,
          child: ClipRect(
            child: _SplashScene(),
          ),
        ),
      ),
    );
  }
}

class _SplashScene extends StatefulWidget {
  const _SplashScene();

  @override
  State<_SplashScene> createState() => _SplashSceneState();
}

class _SplashSceneState extends State<_SplashScene>
    with SingleTickerProviderStateMixin, _Clock {
  static const _gold = Color(0xFFEFBF05);

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: clock,
      builder: (context, _) {
        final t = seconds;
        return Stack(fit: StackFit.expand, children: [
          CustomPaint(painter: _GoldDustPainter(t)),
          Center(child: _glow(t)),
          const Center(child: _SplashLogo()),
          Positioned(
            bottom: 56,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < 3; i++) ...[
                  if (i > 0) const SizedBox(width: 6),
                  _dot(t, i * .15),
                ],
              ],
            ),
          ),
        ]);
      },
    );
  }

  Widget _glow(double t) {
    final phase = (t / 2.2) % 2;
    final p = Curves.easeInOut.transform(phase < 1 ? phase : 2 - phase);
    return Opacity(
      opacity: .55 + .25 * p,
      child: Transform.scale(
        scale: 1 + .12 * p,
        child: Container(
          width: 360,
          height: 360,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                Color.fromRGBO(239, 191, 5, .55),
                Color.fromRGBO(239, 191, 5, .12),
                Color(0x00000000),
              ],
              stops: [0, .45, 1],
            ),
          ),
        ),
      ),
    );
  }

  Widget _dot(double t, double delay) {
    final local = t - delay;
    final f = local < 0 ? 0.0 : local % 1;
    final tri = 1 - (2 * f - 1).abs();
    return Transform.translate(
      offset: Offset(0, -6 * tri),
      child: Opacity(
        opacity: .45 + .55 * tri,
        child: Container(
          width: 7,
          height: 7,
          decoration: const BoxDecoration(color: _gold, shape: BoxShape.circle),
        ),
      ),
    );
  }
}

class _SplashLogo extends StatelessWidget {
  const _SplashLogo();

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 950),
        curve: const Cubic(.2, 1.2, .4, 1),
        builder: (context, v, child) => Opacity(
          opacity: v.clamp(0.0, 1.0),
          child: Transform.scale(scale: .82 + .18 * v, child: child),
        ),
        child: ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) => const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFFFF1A8),
              Color(0xFFEFBF05),
              Color(0xFFB8860B),
              Color(0xFFFFE08A),
            ],
            stops: [0, .35, .7, 1],
          ).createShader(bounds),
          child: Image.asset(
            'assets/images/brand_dark.png',
            height: 168,
            fit: BoxFit.fitHeight,
            filterQuality: FilterQuality.high,
            semanticLabel: 'Midas\'s Touch',
          ),
        ),
      );
}

/// Twinkling gold dust denser near the centre.
class _GoldDustPainter extends CustomPainter {
  _GoldDustPainter(this.t);

  final double t;

  static final _rng = math.Random(42);
  static final List<_Speck> _specks = List.generate(160, (i) {
    final r = _rng.nextDouble();
    // Bias toward centre: square the radius sample.
    final radius = math.sqrt(_rng.nextDouble()) * .72;
    final angle = _rng.nextDouble() * math.pi * 2;
    return _Speck(
      dx: .5 + math.cos(angle) * radius * (0.55 + 0.45 * r),
      dy: .5 + math.sin(angle) * radius * (0.7 + 0.3 * r),
      size: 0.6 + _rng.nextDouble() * 2.4,
      phase: _rng.nextDouble() * math.pi * 2,
      speed: .6 + _rng.nextDouble() * 1.4,
      bright: .25 + _rng.nextDouble() * .75,
    );
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    for (final s in _specks) {
      final twinkle =
          .35 + .65 * (0.5 + 0.5 * math.sin(t * s.speed + s.phase));
      final opacity = (s.bright * twinkle).clamp(0.0, 1.0);
      // Fade toward the edges.
      final cx = (s.dx - .5).abs() * 2;
      final cy = (s.dy - .5).abs() * 2;
      final edge = (1 - math.max(cx, cy) * .85).clamp(0.15, 1.0);
      paint.color = Color.fromRGBO(239, 191, 5, opacity * edge);
      canvas.drawCircle(
        Offset(s.dx * size.width, s.dy * size.height),
        s.size,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _GoldDustPainter old) => old.t != t;
}

class _Speck {
  const _Speck({
    required this.dx,
    required this.dy,
    required this.size,
    required this.phase,
    required this.speed,
    required this.bright,
  });

  final double dx;
  final double dy;
  final double size;
  final double phase;
  final double speed;
  final double bright;
}

/// A coin that spins around its vertical axis (`.cn`).
class FlippingCoin extends StatefulWidget {
  const FlippingCoin({super.key, required this.size});

  final double size;

  @override
  State<FlippingCoin> createState() => _FlippingCoinState();
}

class _FlippingCoinState extends State<FlippingCoin>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1100))
    ..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _c,
        builder: (context, child) => Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()..scale(math.cos(2 * math.pi * _c.value), 1.0),
            child: child),
        child: CoinIcon(size: widget.size),
      );
}

/// `PIL()`: the small "Loading…" pill shown while a tab loads.
class LoadingPill extends StatelessWidget {
  const LoadingPill({super.key});

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    return Positioned(
      top: 64,
      left: 0,
      right: 0,
      child: IgnorePointer(
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: pal.c,
              border: Border.all(color: pal.p),
              borderRadius: BorderRadius.circular(99),
              boxShadow: pal.sh,
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const FlippingCoin(size: 16),
              const SizedBox(width: 6),
              Text('Loading…',
                  style: TextStyle(fontSize: 12, color: pal.tx)),
            ]),
          ),
        ),
      ),
    );
  }
}

/// `FL()`: the full-screen slow-connection state.
class SlowNetworkOverlay extends StatelessWidget {
  const SlowNetworkOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    return Material(
      color: pal.bg,
      child: Container(
        width: double.infinity,
        height: double.infinity,
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const FlippingCoin(size: 56),
          const Padding(
            padding: EdgeInsets.only(top: 4),
            child: Text('Slow connection detected',
                style: TextStyle(fontWeight: FontWeight.w600)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4.2),
            child: Text('Still loading… please wait a moment.',
                textAlign: TextAlign.center,
                style: TextStyle(color: pal.mu)),
          ),
          const _SlidingBar(),
        ]),
      ),
    );
  }
}

class _SlidingBar extends StatefulWidget {
  const _SlidingBar();

  @override
  State<_SlidingBar> createState() => _SlidingBarState();
}

class _SlidingBarState extends State<_SlidingBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1200))
    ..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    return Container(
      width: 180,
      height: 6,
      margin: const EdgeInsets.only(top: 10),
      decoration: BoxDecoration(
          color: pal.pl2, borderRadius: BorderRadius.circular(9)),
      clipBehavior: Clip.antiAlias,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          final p = Curves.easeInOut.transform(_c.value);
          return Stack(children: [
            Positioned(
              left: -72 + (180 + 72) * p,
              width: 72,
              top: 0,
              bottom: 0,
              child: DecoratedBox(
                  decoration: BoxDecoration(
                      color: pal.p, borderRadius: BorderRadius.circular(9))),
            ),
          ]);
        },
      ),
    );
  }
}

/// `#toast`: transient message above the bottom tabs.
class ToastHost extends StatefulWidget {
  const ToastHost({super.key});

  @override
  State<ToastHost> createState() => _ToastHostState();
}

class _ToastHostState extends State<ToastHost> {
  String _message = '';
  bool _visible = false;
  Timer? _timer;
  late final ValueNotifier<ToastEvent?> _source;

  @override
  void initState() {
    super.initState();
    _source = context.read<AppController>().toasts;
    _source.addListener(_onToast);
  }

  void _onToast() {
    final e = _source.value;
    if (e == null) return;
    _timer?.cancel();
    setState(() {
      _message = e.message;
      _visible = true;
    });
    _timer = Timer(const Duration(milliseconds: 2200), () {
      if (mounted) setState(() => _visible = false);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _source.removeListener(_onToast);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 84,
      child: IgnorePointer(
        child: AnimatedSlide(
          duration: const Duration(milliseconds: 250),
          offset: _visible ? Offset.zero : const Offset(0, .6),
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 250),
            opacity: _visible ? 1 : 0,
            child: Center(
              child: Material(
                type: MaterialType.transparency,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                      color: Brand.toastBg,
                      borderRadius: BorderRadius.circular(12)),
                  child: Text(_message,
                      maxLines: 1,
                      softWrap: false,
                      style: const TextStyle(
                          color: Color(0xFFFCF4D3),
                          fontSize: 13,
                          height: 1.45)),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

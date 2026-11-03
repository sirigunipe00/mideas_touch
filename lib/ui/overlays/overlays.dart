import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../app/app_controller.dart';
import '../../core/theme/palette.dart';
import '../../state/nav_cubit.dart';
import '../widgets/coin.dart';
import '../widgets/common.dart';

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

/// `SPL()`: the animated splash screen.
class SplashOverlay extends StatefulWidget {
  const SplashOverlay({super.key});

  @override
  State<SplashOverlay> createState() => _SplashOverlayState();
}

class _SplashOverlayState extends State<SplashOverlay>
    with SingleTickerProviderStateMixin, _Clock {
  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: context.read<NavCubit>().dismissSplash,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 400),
        builder: (context, v, child) => Opacity(opacity: v, child: child),
        child: Container(
          color: pal.bg,
          child: ClipRect(
            child: LayoutBuilder(builder: (context, c) {
              return AnimatedBuilder(
                animation: clock,
                builder: (context, _) {
                  final t = seconds;
                  return Stack(clipBehavior: Clip.none, children: [
                    Center(child: _glow(t)),
                    for (var i = 0; i < 14; i++) _coin(i, t, c.maxWidth),
                    const Center(child: _SplashLogo()),
                    Positioned(
                      bottom: 60,
                      left: 0,
                      right: 0,
                      child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            for (var i = 0; i < 3; i++) ...[
                              if (i > 0) const SizedBox(width: 6),
                              _dot(t, i * .15),
                            ]
                          ]),
                    ),
                  ]);
                },
              );
            }),
          ),
        ),
      ),
    );
  }

  Widget _glow(double t) {
    final phase = (t / 1.6) % 2;
    final p = Curves.easeInOut.transform(phase < 1 ? phase : 2 - phase);
    return Opacity(
      opacity: 1 - .3 * p,
      child: Transform.scale(
        scale: 1 + .25 * p,
        child: Container(
          width: 340,
          height: 340,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
                colors: [Color.fromRGBO(239, 191, 5, .45), Color(0x00EFBF05)],
                stops: [0, .7]),
          ),
        ),
      ),
    );
  }

  Widget _coin(int i, double t, double width) {
    final delay = (i % 7) * .28;
    final dur = 1.8 + (i % 4) * .35;
    final local = t - delay;
    final phase = local < 0 ? 0.0 : (local % dur) / dur;
    final left = ((i * 37 + 8) % 92) / 100 * width;
    return Positioned(
      left: left,
      top: -40 + 1000 * phase,
      child: Transform.rotate(
          angle: 2 * math.pi * phase, child: const CoinIcon(size: 26)),
    );
  }

  Widget _dot(double t, double delay) {
    final local = t - delay;
    final f = local < 0 ? 0.0 : local % 1;
    final tri = 1 - (2 * f - 1).abs();
    return Transform.translate(
      offset: Offset(0, -8 * tri),
      child: Opacity(
        opacity: 1 - .6 * tri,
        child: Container(
          width: 8,
          height: 8,
          decoration:
              BoxDecoration(color: context.pal.p, shape: BoxShape.circle),
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
        duration: const Duration(milliseconds: 900),
        curve: const Cubic(.2, 1.4, .4, 1),
        builder: (context, v, child) => Opacity(
          opacity: v.clamp(0.0, 1.0),
          child: Transform.rotate(
            angle: -8 * math.pi / 180 * (1 - v),
            child: Transform.scale(scale: .3 + .7 * v, child: child),
          ),
        ),
        child: const BrandLogo(height: 150),
      );
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

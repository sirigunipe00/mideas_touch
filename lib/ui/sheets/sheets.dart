import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../app/app_controller.dart';
import '../../core/theme/palette.dart';
import '../../state/catalog_cubit.dart';
import '../../state/editor_cubit.dart';
import '../../state/nav_cubit.dart';
import '../../state/session_cubit.dart';
import '../../state/settings_cubit.dart';
import '../widgets/coin.dart';
import '../widgets/common.dart';
import '../widgets/color_picker.dart';
import '../widgets/kit.dart';
import '../widgets/synced_fields.dart';

/// `SH()`: the bottom sheet / modal layer. Rendered above the current screen
/// whenever [NavState.sheet] is set; tapping the scrim dismisses it.
class SheetOverlay extends StatelessWidget {
  const SheetOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    final sheet = context.select<NavCubit, AppSheet?>((c) => c.state.sheet);
    if (sheet == null) return const SizedBox();
    return SheetScrim(
      key: ValueKey(sheet.runtimeType),
      onDismiss: context.read<NavCubit>().closeSheet,
      child: _SheetBody(sheet),
    );
  }
}

/// `.ovl` + `.shx`: dimmed scrim with a sheet that slides up (or a centred
/// card when [centered]).
class SheetScrim extends StatelessWidget {
  const SheetScrim({
    super.key,
    required this.child,
    this.onDismiss,
    this.centered = false,
  });

  final Widget child;
  final VoidCallback? onDismiss;
  final bool centered;

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    final safeBottom = MediaQuery.of(context).viewPadding.bottom;
    return Material(
      type: MaterialType.transparency,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onDismiss,
        child: Container(
          color: const Color.fromRGBO(10, 8, 0, .55),
          alignment: centered ? Alignment.center : Alignment.bottomCenter,
          padding: EdgeInsets.all(centered ? 18 : 0),
          child: LayoutBuilder(builder: (context, c) {
            return GestureDetector(
              onTap: () {},
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: const Duration(milliseconds: 220),
                builder: (context, v, child) => Opacity(
                  opacity: v,
                  child: Transform.translate(
                      offset: Offset(0, 40 * (1 - v)), child: child),
                ),
                child: Container(
                  width: double.infinity,
                  constraints: BoxConstraints(maxHeight: c.maxHeight * .9),
                  padding: EdgeInsets.fromLTRB(
                      18, 10, 18, 18 + (centered ? 0 : safeBottom)),
                  decoration: BoxDecoration(
                    color: pal.c,
                    borderRadius: centered
                        ? BorderRadius.circular(26)
                        : const BorderRadius.vertical(
                            top: Radius.circular(24)),
                  ),
                  child: SingleChildScrollView(
                    child: DefaultTextStyle.merge(
                      style: TextStyle(color: pal.tx),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: centered
                            ? CrossAxisAlignment.center
                            : CrossAxisAlignment.stretch,
                        children: [
                          if (!centered) const _Grab(),
                          child,
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}

class _Grab extends StatelessWidget {
  const _Grab();

  @override
  Widget build(BuildContext context) => Center(
        child: Container(
          width: 40,
          height: 4,
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
              color: context.pal.ln, borderRadius: BorderRadius.circular(9)),
        ),
      );
}

/// `h3` inside a sheet.
class SheetTitle extends StatelessWidget {
  const SheetTitle(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => CoinText(text,
      coinSize: 18,
      style: const TextStyle(
          fontSize: 16.38,
          fontWeight: kBold,
          height: 1.45,
          leadingDistribution: TextLeadingDistribution.even));
}

/// `p.mu` inside a sheet.
class SheetText extends StatelessWidget {
  const SheetText(this.text, {super.key, this.size, this.align});

  final String text;
  final double? size;
  final TextAlign? align;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4.2),
        child: CoinText(text,
            textAlign: align,
            style: TextStyle(color: context.pal.mu, fontSize: size)),
      );
}

class _SheetBody extends StatelessWidget {
  const _SheetBody(this.sheet);

  final AppSheet sheet;

  @override
  Widget build(BuildContext context) {
    return switch (sheet) {
      RegisterSheet() => const _RegisterContent(),
      NoCoinsSheet() => const _NoCoinsContent(),
      final UnlockSheet s => _UnlockContent(s.designId),
      SendCoinsSheet() => const _SendContent(),
      DownloadedSheet() => const _DownloadedContent(),
      ExportSheet() => const _ExportContent(),
      ShareSheet() => const _ShareContent(),
      LinkSheet() => const _LinkContent(),
      ActionsSheet() => const _ActionsContent(),
      InviteSheet() => const _InviteContent(),
      final ErrorSheet s => _ErrorContent(s.label),
      ImageSearchSheet() => const _ImageSearchContent(),
    };
  }
}

class _RegisterContent extends StatefulWidget {
  const _RegisterContent();

  @override
  State<_RegisterContent> createState() => _RegisterContentState();
}

class _RegisterContentState extends State<_RegisterContent> {
  final _email = TextEditingController();
  final _password = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _submit() =>
      context.app.submitAuth(email: _email.text, password: _password.text);

  @override
  Widget build(BuildContext context) {
    final s = context.watch<SessionCubit>().state;
    final session = context.read<SessionCubit>();
    final reg = s.registering;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SheetTitle(reg ? 'Create your account' : 'Login'),
      const SheetText('Register to customise with coins and download your designs.'),
      Segmented(
        options: const ['Register', 'Login'],
        selected: reg ? 'Register' : 'Login',
        onChanged: (v) => session.setRegistering(v == 'Register'),
      ),
      if (reg) ...[
        LiveTextField(
            value: s.fullName, hint: 'Full name', onChanged: session.setFullName),
        const SizedBox(height: 10),
      ],
      AppField(
          controller: _email,
          hint: 'Email',
          keyboardType: TextInputType.emailAddress),
      const SizedBox(height: 10),
      AppField(
          controller: _password,
          hint: 'Password',
          obscure: true,
          onSubmitted: (_) => _submit()),
      const SizedBox(height: 6),
      AppButton(
          s.busy ? 'Please wait…' : (reg ? 'Create Account' : 'Login'),
          wide: true,
          onTap: s.busy ? null : _submit),
    ]);
  }
}

class _NoCoinsContent extends StatelessWidget {
  const _NoCoinsContent();

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const SheetTitle('🪙 You need 1 coin'),
      const SheetText(
          'Customising a design uses 1 coin. Once unlocked, you can use that design again anytime.'),
      const SizedBox(height: 10),
      AppButton('Get coins',
          wide: true,
          onTap: () => context.read<NavCubit>().go(AppView.wallet)),
    ]);
  }
}

class _UnlockContent extends StatelessWidget {
  const _UnlockContent(this.id);

  final int id;

  @override
  Widget build(BuildContext context) {
    final d = context.read<CatalogCubit>().state.byId(id);
    final coins = context.watch<SessionCubit>().state.coins;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SheetTitle('Unlock “${d?.name ?? ''}”?'),
      SheetText(
          'This uses 1 coin. Balance: $coins → ${coins - 1}. You can reuse this design anytime on your account.'),
      const SizedBox(height: 10),
      AppButton('Unlock & Customise', wide: true, onTap: context.app.unlock),
      const SizedBox(height: 8),
      AppButton('Not now',
          style: BtnStyle.ghost,
          wide: true,
          onTap: context.read<NavCubit>().closeSheet),
    ]);
  }
}

class _SendContent extends StatefulWidget {
  const _SendContent();

  @override
  State<_SendContent> createState() => _SendContentState();
}

class _SendContentState extends State<_SendContent> {
  final _to = TextEditingController();
  final _amount = TextEditingController();

  @override
  void dispose() {
    _to.dispose();
    _amount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final coins = context.watch<SessionCubit>().state.coins;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const SheetTitle('Send coins'),
      SheetText('Balance: 🪙 $coins'),
      AppField(controller: _to, hint: 'Friend’s mobile number or email'),
      const SizedBox(height: 8),
      AppField(
          controller: _amount,
          hint: 'Number of coins',
          keyboardType: TextInputType.number),
      const SizedBox(height: 12),
      AppButton('Send',
          wide: true, onTap: () => context.app.sendCoins(_to.text, _amount.text)),
    ]);
  }
}

class _DownloadedContent extends StatelessWidget {
  const _DownloadedContent();

  @override
  Widget build(BuildContext context) {
    final e = context.watch<EditorCubit>().state;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const SheetTitle('✓ Downloaded'),
      SheetText('${e.fileName}.jpg is saved to your downloads.'),
      if (e.exportImage != null)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.memory(e.exportImage!, fit: BoxFit.fitWidth)),
        ),
      const SheetText(
          'If your browser blocks the download, press and hold the image to save it.',
          size: 11),
      AppButton('Done',
          wide: true, onTap: context.read<NavCubit>().closeSheet),
    ]);
  }
}

class _ExportContent extends StatefulWidget {
  const _ExportContent();

  @override
  State<_ExportContent> createState() => _ExportContentState();
}

class _ExportContentState extends State<_ExportContent> {
  double? _dragging;

  /// `step=0.05`
  double _snap(double v) => (v * 20).round() / 20;

  @override
  Widget build(BuildContext context) {
    final t = context.watch<SettingsCubit>().state.t;
    final e = context.watch<EditorCubit>().state;
    final editor = context.read<EditorCubit>();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SheetTitle(t('exp')),
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: e.exportImage != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.memory(e.exportImage!, fit: BoxFit.fitWidth))
            : const Skeleton(height: 300),
      ),
      const FieldLabel('File name'),
      LiveTextField(value: e.fileName, onChanged: editor.setFileName),
      FieldLabel('Quality ${(e.quality * 100).round()}%'),
      ThemedSlider(
        value: _dragging ?? e.quality,
        min: .5,
        max: 1,
        onChanged: (v) => setState(() => _dragging = _snap(v)),
        onChangeEnd: (v) {
          setState(() => _dragging = null);
          context.app.setExportQuality(_snap(v));
        },
      ),
      const SizedBox(height: 12),
      const SheetText('Free download includes a Midas’s Touch watermark.',
          size: 11),
      const SizedBox(height: 2),
      AppButton('Download JPG', wide: true, onTap: context.app.download),
    ]);
  }
}

class _ShareContent extends StatelessWidget {
  const _ShareContent();

  @override
  Widget build(BuildContext context) {
    final t = context.watch<SettingsCubit>().state.t;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SheetTitle(t('share')),
      const SheetText('Share as a file or as a link.'),
      AppButton('Download & Share',
          wide: true, onTap: context.app.downloadAndShare),
      const SizedBox(height: 8),
      AppButton('Share Link',
          style: BtnStyle.ghost,
          wide: true,
          onTap: () => context.read<NavCubit>().openSheet(const LinkSheet())),
    ]);
  }
}

class _LinkContent extends StatefulWidget {
  const _LinkContent();

  @override
  State<_LinkContent> createState() => _LinkContentState();
}

class _LinkContentState extends State<_LinkContent> {
  bool _ready = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(const Duration(milliseconds: 1100), () {
      if (mounted) setState(() => _ready = true);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return const Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SheetTitle('Generating link...'),
            SizedBox(height: 14),
            Skeleton(height: 50),
          ]);
    }
    final app = context.app;
    final d = context.read<EditorCubit>().state.design!;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const SheetTitle('Your shareable link is ready'),
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: _ReadOnlyField(app.shareLinkFor(d)),
      ),
      Row(children: [
        Expanded(child: AppButton('Copy Link', wide: true, onTap: () => app.copyLink(d))),
        const SizedBox(width: 8),
        Expanded(
            child: AppButton('Share Link',
                style: BtnStyle.ghost, wide: true, onTap: () => app.shareLink(d))),
      ]),
      const SizedBox(height: 8),
      AppButton('Open Shared Creative',
          style: BtnStyle.ghost,
          wide: true,
          onTap: () => context.read<NavCubit>().go(AppView.sharedView)),
    ]);
  }
}

class _ReadOnlyField extends StatefulWidget {
  const _ReadOnlyField(this.value);

  final String value;

  @override
  State<_ReadOnlyField> createState() => _ReadOnlyFieldState();
}

class _ReadOnlyFieldState extends State<_ReadOnlyField> {
  late final TextEditingController _c =
      TextEditingController(text: widget.value);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AppField(controller: _c, readOnly: true);
}

class _ActionsContent extends StatelessWidget {
  const _ActionsContent();

  @override
  Widget build(BuildContext context) {
    final d = context.watch<EditorCubit>().state.design;
    if (d == null) return const SizedBox();
    final nav = context.read<NavCubit>();
    final app = context.app;
    Widget row(String label, VoidCallback onTap) => MenuRow(
          margin: const EdgeInsets.symmetric(vertical: 8),
          onTap: onTap,
          trailing: const Text('›'),
          child: Text(label),
        );
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SheetTitle(d.name),
      SheetText('Last edited: ${d.mod}'),
      row('Edit', () => app.editSaved(d.id)),
      row('Preview', () => nav.go(AppView.preview)),
      row('Share', () {
        nav.go(AppView.preview);
        nav.openSheet(const ShareSheet());
      }),
      row('Delete', () => app.deleteSaved(d.id)),
    ]);
  }
}

class _InviteContent extends StatelessWidget {
  const _InviteContent();

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final pal = context.pal;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const SheetTitle('🤝 Invite a friend'),
      const SheetText('Share this message with your friend:'),
      Container(
        margin: const EdgeInsets.symmetric(vertical: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
            color: pal.c, borderRadius: BorderRadius.circular(14)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text(AppController.inviteMessage,
              style: TextStyle(fontWeight: kSemi)),
          SheetText(app.inviteUrl, size: 12),
        ]),
      ),
      Row(children: [
        Expanded(child: AppButton('Share', wide: true, onTap: app.inviteShare)),
        const SizedBox(width: 8),
        Expanded(
            child: AppButton('Copy',
                style: BtnStyle.ghost, wide: true, onTap: app.inviteCopy)),
      ]),
    ]);
  }
}

class _ErrorContent extends StatelessWidget {
  const _ErrorContent(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SheetTitle('⚠ $label'),
      const SheetText('Something went wrong. Please try again.'),
      const SizedBox(height: 4),
      AppButton('Retry', wide: true, onTap: () {
        context.read<NavCubit>().closeSheet();
        context.app.toast('Retrying...');
      }),
    ]);
  }
}

class _ImageSearchContent extends StatelessWidget {
  const _ImageSearchContent();

  @override
  Widget build(BuildContext context) {
    final t = context.watch<SettingsCubit>().state.t;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SheetTitle(t('sbi')),
      const SheetText(
          'Pick a sample image to find similar designs and assets. Uploads are not available in Phase 1.'),
      ArtifactGrid(columns: 4, padding: EdgeInsets.zero, children: [
        for (final a in context.read<CatalogCubit>().state.assets.take(8))
          AssetCell(a.emoji,
              onTap: () => context.app.chooseCategory(a.keywords.split(' ').first)),
      ]),
    ]);
  }
}

/// `INTRO()`: the first-launch welcome card.
class IntroOverlay extends StatelessWidget {
  const IntroOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.watch<SettingsCubit>().state.t;
    return SheetScrim(
      centered: true,
      child: Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
        const SizedBox(height: 6),
        Text(t.introTitle,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 17, fontWeight: kBold)),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(children: [
            for (final p in t.introPoints)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(children: [
                  CoinText(p[0], coinSize: 22, style: const TextStyle(fontSize: 22)),
                  const SizedBox(width: 8),
                  Expanded(child: CoinText(p[1])),
                ]),
              ),
          ]),
        ),
        const Padding(
          padding: EdgeInsets.only(bottom: 12),
          child: LanguageSwitch(),
        ),
        AppButton(t.introStart,
            wide: true, onTap: context.read<NavCubit>().dismissIntro),
      ]),
    );
  }
}

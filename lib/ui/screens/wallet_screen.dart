import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../app/app_controller.dart';
import '../../core/theme/css_gradient.dart';
import '../../core/theme/palette.dart';
import '../../data/catalog.dart';
import '../../models/account.dart';
import '../../state/nav_cubit.dart';
import '../../state/session_cubit.dart';
import '../widgets/coin.dart';
import '../widgets/common.dart';
import '../widgets/kit.dart';

class WalletScreen extends StatelessWidget {
  const WalletScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    final s = context.watch<SessionCubit>().state;
    final app = context.app;
    return Column(children: [
      const BackHeader('My Coins'),
      Expanded(
        child: ListView(padding: EdgeInsets.zero, children: [
          _BalanceCard(coins: s.coins),
          const SectionTitle('Earn coins'),
          _TaskRow(
              icon: '📣',
              label: 'Follow us',
              subtitle: 'On our social media pages',
              done: s.done['f'] == true,
              onTap: () => app.earn('f', 'Followed us')),
          if (s.inviteSent && s.done['r'] != true)
            MenuRow(
              trailing: AppButton('Simulate accepted',
                  small: true,
                  style: BtnStyle.ghost,
                  onTap: () => app.earn('r', 'Friend accepted your invite')),
              child: const _TaskText('🤝', 'Refer a friend',
                  'Invite sent. You get 1 coin when they accept.'),
            )
          else
            _TaskRow(
                icon: '🤝',
                label: 'Refer a friend',
                subtitle: '1 coin when your friend accepts',
                done: s.done['r'] == true,
                button: 'Invite',
                onTap: () => context
                    .read<NavCubit>()
                    .openSheet(const InviteSheet())),
          _TaskRow(
              icon: '🏷️',
              label: 'Tag us',
              subtitle: 'Tag Midas’s Touch in your post',
              done: s.done['t'] == true,
              onTap: () => app.earn('t', 'Tagged us')),
          const SectionTitle('Buy coins'),
          for (var i = 0; i < Catalog.coinPacks.length; i++)
            _PlanCard(
                pack: Catalog.coinPacks[i],
                popular: i == 1,
                onBuy: () => app.buy(Catalog.coinPacks[i])),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4.2),
            child: Text(
                'Payment is a placeholder for a future integration (UPI may be added later).',
                style: TextStyle(fontSize: 11, color: pal.mu)),
          ),
          const SectionTitle('History'),
          if (s.history.isNotEmpty)
            for (final x in s.history)
              MenuRow(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                trailing: Text('${x.amount > 0 ? '+' : ''}${x.amount}',
                    style: TextStyle(
                        fontWeight: kSemi,
                        color: x.amount > 0 ? Brand.green : Brand.red)),
                child: Text(x.label),
              )
          else
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 4.2),
              child: Text('No activity yet.', style: TextStyle(color: pal.mu)),
            ),
          const SizedBox(height: 20),
        ]),
      ),
    ]);
  }
}

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({required this.coins});

  final int coins;

  @override
  Widget build(BuildContext context) {
    const ink = Color(0xFF2A1C00);
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: const CssLinearGradient(
            135,
            [Color(0xFFFFE27A), Color(0xFFF5B800), Color(0xFFD99A00)],
            [0, .55, 1]),
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(
              color: Color.fromRGBO(184, 134, 11, .35),
              blurRadius: 18,
              offset: Offset(0, 6)),
        ],
      ),
      child: Stack(children: [
        Positioned(
          right: -30,
          top: -30,
          child: Container(
            width: 130,
            height: 130,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(colors: [
                Color.fromRGBO(255, 255, 255, .45),
                Color.fromRGBO(255, 255, 255, 0),
              ], stops: [
                0,
                .7
              ]),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(18),
          child: DefaultTextStyle.merge(
            style: const TextStyle(color: ink),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Opacity(
                      opacity: .8,
                      child: Text('Balance',
                          style:
                              TextStyle(fontSize: 11.67, fontWeight: kSemi))),
                  CoinText('🪙 $coins',
                      coinSize: 30,
                      style: const TextStyle(
                          fontSize: 26,
                          fontWeight: kBold,
                          height: 1.2,
                          leadingDistribution: TextLeadingDistribution.even)),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 4.2),
                    child: Text(
                        '1 coin customises 1 design. Reuse it later on your account.',
                        style: TextStyle(fontSize: 12)),
                  ),
                  const SizedBox(height: 6),
                  AppButton('Send coins',
                      small: true,
                      background: ink,
                      foreground: const Color(0xFFFFE27A),
                      onTap: () => context
                          .read<NavCubit>()
                          .openSheet(const SendCoinsSheet())),
                ]),
          ),
        ),
      ]),
    );
  }
}

class _TaskText extends StatelessWidget {
  const _TaskText(this.icon, this.label, this.subtitle);

  final String icon;
  final String label;
  final String subtitle;

  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        CoinText('$icon $label'),
        Text(subtitle,
            style: TextStyle(fontSize: 11.67, color: context.pal.mu)),
      ]);
}

class _TaskRow extends StatelessWidget {
  const _TaskRow({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.done,
    required this.onTap,
    this.button = '+1 🪙',
  });

  final String icon;
  final String label;
  final String subtitle;
  final bool done;
  final VoidCallback onTap;
  final String button;

  @override
  Widget build(BuildContext context) => MenuRow(
        trailing: done
            ? const Tag('✓ Done')
            : AppButton(button, small: true, onTap: onTap),
        child: _TaskText(icon, label, subtitle),
      );
}

class _PlanCard extends StatelessWidget {
  const _PlanCard(
      {required this.pack, required this.popular, required this.onBuy});

  final CoinPack pack;
  final bool popular;
  final VoidCallback onBuy;

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Stack(clipBehavior: Clip.none, children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: popular ? pal.pl : pal.c,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: popular ? pal.p : pal.ln, width: popular ? 2 : 1),
            boxShadow: pal.sh,
          ),
          child: Row(children: [
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(pack.name,
                        style:
                            const TextStyle(fontSize: 16, fontWeight: kSemi)),
                    CoinText(
                        '🪙 ${pack.coins}${pack.bonus > 0 ? ' + ${pack.bonus} bonus' : ''} coin${pack.total > 1 ? 's' : ''}',
                        style: TextStyle(color: pal.mu)),
                  ]),
            ),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('₹${pack.price}',
                  style: const TextStyle(fontSize: 20, fontWeight: kSemi)),
              const SizedBox(height: 4),
              AppButton('Buy', small: true, onTap: onBuy),
            ]),
          ]),
        ),
        if (popular)
          Positioned(
            top: -11,
            left: 14,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
              decoration: BoxDecoration(
                  color: pal.p, borderRadius: BorderRadius.circular(99)),
              child: Text('★ Most Popular Plan (Best Seller)',
                  style: TextStyle(
                      fontSize: 11, fontWeight: kBold, color: pal.pt)),
            ),
          ),
      ]),
    );
  }
}

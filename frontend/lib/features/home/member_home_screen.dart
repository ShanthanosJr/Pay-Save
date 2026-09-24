import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_controller.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/ps_arithmetic_row.dart';
import '../../core/widgets/ps_chip_row.dart';
import '../../core/widgets/ps_circle_switcher.dart';
import '../../core/widgets/ps_grid_tile.dart';
import '../../core/widgets/ps_hero_cycle_card.dart';
import '../../core/widgets/ps_search_field.dart';
import '../../core/widgets/ps_status_badge.dart';
import '../../l10n/gen/app_localizations.dart';

/// Placeholder Member Home with hard-coded sample circle data. Real data
/// (from `v_cycle_member_status`) arrives with the ledger phase.
class MemberHomeScreen extends ConsumerStatefulWidget {
  const MemberHomeScreen({super.key});

  @override
  ConsumerState<MemberHomeScreen> createState() => _MemberHomeScreenState();
}

class _MemberHomeScreenState extends ConsumerState<MemberHomeScreen> {
  int _chipIndex = 0;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final auth = ref.watch(authControllerProvider);
    final name = auth is AuthLoggedIn ? auth.user.firstName : '';

    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(AppSpace.screen, AppSpace.s, AppSpace.screen, AppSpace.xxl),
            children: [
              const Row(children: [PsCircleSwitcher(circleName: 'Friends Seettu')]),
              const SizedBox(height: AppSpace.m),
              Text(l10n.greeting(name), style: AppText.headline),
              const SizedBox(height: AppSpace.l),
              PsSearchField(hintText: l10n.searchHint, filterLabel: l10n.filterLabel),
              const SizedBox(height: AppSpace.xl),
              Text(l10n.thisCycle, style: AppText.title),
              const SizedBox(height: AppSpace.m),
              PsHeroCycleCard(
                circleName: 'Friends Seettu',
                cycleLabel: l10n.cycleOf(3, 5),
                amountLabel: 'LKR 5,000',
                status: ContributionStatus.due,
                statusLabel: l10n.dueInDays('20 Sep', 3),
                payNowLabel: l10n.payNow,
                viewRecordLabel: l10n.viewRecord,
                tagLabel: l10n.chipTurnOrder,
                onPayNow: () {},
              ),
              const SizedBox(height: AppSpace.xl),
              PsChipRow(
                labels: [l10n.chipTurnOrder, l10n.chipHistory, l10n.chipSavings, l10n.chipReminders],
                selectedIndex: _chipIndex,
                onSelected: (i) => setState(() => _chipIndex = i),
              ),
              const SizedBox(height: AppSpace.l),
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                mainAxisSpacing: AppSpace.m,
                crossAxisSpacing: AppSpace.m,
                childAspectRatio: 1.05,
                children: [
                  PsGridTile(
                    icon: Icons.swap_horiz,
                    title: l10n.turnOrderTile,
                    subtitle: l10n.nextYourTurn,
                    caption: l10n.cycleNumberShort(5),
                  ),
                  PsGridTile(
                    icon: Icons.savings_outlined,
                    title: l10n.mySavingsTile,
                    subtitle: 'LKR 15,000',
                    caption: l10n.verifiedCount(3),
                  ),
                ],
              ),
              const SizedBox(height: AppSpace.m),
              const Divider(color: AppColors.hairline, height: 1),
              PsArithmeticRow(
                summary: l10n.arithmeticSummary(3, l10n.statusVerified.toLowerCase(), '5,000', '15,000'),
                totalLabel: 'LKR 15,000',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/ps_arithmetic_row.dart';
import '../../core/widgets/ps_chip_row.dart';
import '../../core/widgets/ps_circle_switcher.dart';
import '../../core/widgets/ps_grid_tile.dart';
import '../../core/widgets/ps_hero_cycle_card.dart';
import '../../core/widgets/ps_pager_dots.dart';
import '../../core/widgets/ps_search_field.dart';
import '../../core/widgets/ps_status_badge.dart';
import '../../l10n/gen/app_localizations.dart';

/// Placeholder Member Home (design-system §4.2), Phase 0: hard-coded sample
/// data only. Real data (from `v_cycle_member_status`) arrives in Phase 3+.
class MemberHomeScreen extends StatefulWidget {
  const MemberHomeScreen({super.key});

  @override
  State<MemberHomeScreen> createState() => _MemberHomeScreenState();
}

class _MemberHomeScreenState extends State<MemberHomeScreen> {
  int _navIndex = 0;
  int _chipIndex = 0;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: AppSpace.screen, vertical: AppSpace.l),
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const PsCircleSwitcher(circleName: 'Friends Seettu'),
                const Icon(Icons.notifications_none, color: AppColors.textPrimary),
              ],
            ),
            const SizedBox(height: AppSpace.m),
            Text(l10n.goodMorning('Nadeeshi'), style: AppText.greeting),
            const SizedBox(height: AppSpace.l),
            PsSearchField(hintText: l10n.searchHint),
            const SizedBox(height: AppSpace.xl),
            Text(l10n.thisCycle, style: AppText.section),
            const SizedBox(height: AppSpace.m),
            PsHeroCycleCard(
              circleName: 'Friends Seettu',
              cycleLabel: l10n.cycleOf(3, 5),
              amountLabel: 'LKR 5,000',
              status: ContributionStatus.due,
              statusLabel: l10n.dueInDays('20 Sep', 3),
              payNowLabel: l10n.payNow,
              viewRecordLabel: l10n.viewRecord,
              onPayNow: () {},
            ),
            const SizedBox(height: AppSpace.m),
            const Center(child: PsPagerDots(count: 3, activeIndex: 0)),
            const SizedBox(height: AppSpace.l),
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
              childAspectRatio: 0.95,
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
                  onAddTap: () {},
                ),
              ],
            ),
            const SizedBox(height: AppSpace.l),
            PsArithmeticRow(
              summary: l10n.arithmeticSummary(3, l10n.statusVerified.toLowerCase(), '5,000', '15,000'),
              totalLabel: 'LKR 15,000',
            ),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _navIndex,
        onDestinationSelected: (i) => setState(() => _navIndex = i),
        destinations: [
          NavigationDestination(icon: const Icon(Icons.home_outlined), label: l10n.navHome),
          NavigationDestination(icon: const Icon(Icons.groups_outlined), label: l10n.navCircles),
          NavigationDestination(icon: const Icon(Icons.history), label: l10n.navHistory),
          NavigationDestination(icon: const Icon(Icons.settings_outlined), label: l10n.navSettings),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/social/social_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/ps_back_header.dart';
import '../../core/widgets/ps_button.dart';
import '../../core/widgets/ps_forest_page.dart';
import '../../l10n/gen/app_localizations.dart';
import 'person_row.dart';

/// Followers or following of one member.
class PeopleListScreen extends ConsumerWidget {
  const PeopleListScreen({super.key, required this.userId, required this.kind});

  final String userId;
  final PeopleListKind kind;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final key = (userId, kind);
    final async = ref.watch(peopleListProvider(key));

    return Scaffold(
      body: PsForestPage(
        header: PsBackHeader(
          title: switch (kind) {
            PeopleListKind.followers => l10n.followersLabel,
            PeopleListKind.following => l10n.followingLabel,
            PeopleListKind.pals => l10n.palsLabel,
          },
          backLabel: l10n.backLabel,
        ),
        children: [
          ...async.when(
            loading: () => const [
              Padding(
                padding: EdgeInsets.only(top: 48),
                child: Center(child: CircularProgressIndicator(color: AppColors.forest700, strokeWidth: 2)),
              ),
            ],
            error: (_, _) => [
              Text(l10n.loadFailed, textAlign: TextAlign.center, style: AppText.body),
              const SizedBox(height: AppSpace.l),
              Center(
                child: PsButton(
                  label: l10n.retryLabel,
                  variant: PsButtonVariant.secondary,
                  compact: true,
                  expand: false,
                  onPressed: () => ref.invalidate(peopleListProvider(key)),
                ),
              ),
            ],
            data: (people) => people.isEmpty
                ? [Text(l10n.noPeopleYet, textAlign: TextAlign.center, style: AppText.body)]
                : [for (final p in people) PersonRow(person: p, onTap: () => context.push('/people/${p.id}'))],
          ),
        ],
      ),
    );
  }
}

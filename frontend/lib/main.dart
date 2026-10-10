import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/auth/auth_controller.dart';
import 'core/providers/locale_provider.dart';
import 'core/providers/text_scale_provider.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/widgets/ps_brand_loader.dart';
import 'l10n/gen/app_localizations.dart';

void main() {
  runApp(const ProviderScope(child: PayAndSaveApp()));
}

class PayAndSaveApp extends ConsumerWidget {
  const PayAndSaveApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    final locale = ref.watch(localeProvider);
    final textSize = ref.watch(textScaleProvider);

    return MaterialApp.router(
      title: 'Pay&Save',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      scrollBehavior: const _AppScrollBehavior(),
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      routerConfig: router,
      builder: (context, child) {
        final mq = MediaQuery.of(context);
        return MediaQuery(
          data: mq.copyWith(textScaler: TextScaler.linear(mq.textScaler.scale(1) * textSize.factor)),
          // The branded loader covers the app until the saved session has
          // been checked, then fades out over the first real screen.
          child: Consumer(
            builder: (context, ref, _) => PsSplashGate(
              ready: ref.watch(authControllerProvider.select((a) => a is! AuthUnknown)),
              child: child!,
            ),
          ),
        );
      },
    );
  }
}

/// Lists stop at their ends instead of Android's default overscroll effect,
/// which stretches the whole page, text included.
class _AppScrollBehavior extends MaterialScrollBehavior {
  const _AppScrollBehavior();

  @override
  Widget buildOverscrollIndicator(BuildContext context, Widget child, ScrollableDetails details) => child;

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) => const ClampingScrollPhysics();
}

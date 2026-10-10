import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pay_and_save/core/widgets/ps_brand_loader.dart';
import 'package:pay_and_save/core/widgets/ps_skeleton.dart';
import 'package:pay_and_save/l10n/gen/app_localizations.dart';

import 'support/pump.dart';

Widget _host(Widget child, {bool reduceMotion = false}) => MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, c) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: reduceMotion),
        child: c!,
      ),
      home: Scaffold(body: child),
    );

void main() {
  testWidgets('App start shows the branded loader, then reveals the first screen', (tester) async {
    final gate = ValueNotifier(false);
    await tester.pumpWidget(_host(ValueListenableBuilder(
      valueListenable: gate,
      builder: (context, ready, _) => PsSplashGate(ready: ready, child: const Text('first screen')),
    )));
    expect(find.byType(PsBrandLoader), findsOneWidget);

    // Ready before the mark has finished drawing: the loader stays up.
    gate.value = true;
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(PsBrandLoader), findsOneWidget);

    await tester.pumpAndSettle();
    expect(find.byType(PsBrandLoader), findsNothing);
    expect(find.text('first screen'), findsOneWidget);
  });

  testWidgets('The loader waits for the session check even after the mark has drawn', (tester) async {
    final gate = ValueNotifier(false);
    await tester.pumpWidget(_host(ValueListenableBuilder(
      valueListenable: gate,
      builder: (context, ready, _) => PsSplashGate(ready: ready, child: const Text('first screen')),
    )));
    await tester.pump(const Duration(seconds: 5));
    expect(find.byType(PsBrandLoader), findsOneWidget);

    gate.value = true;
    await tester.pumpAndSettle();
    expect(find.byType(PsBrandLoader), findsNothing);
  });

  testWidgets('Signing in shows the branded loader until the server answers', (tester) async {
    final (_, api, _) = await pumpApp(tester);
    api.loginGate = Completer<void>();
    await tester.tap(find.text('Log in'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(0), 'me@example.com');
    await tester.enterText(find.byType(TextFormField).at(1), 'secret123');
    await tester.tap(find.widgetWithText(InkWell, 'Log in').last);
    await tester.pump(const Duration(seconds: 2));

    expect(find.byType(PsBrandLoader), findsOneWidget);
    expect(find.text('Signing you in…'), findsOneWidget);

    api.loginGate!.complete();
    await tester.pumpAndSettle();
    expect(find.byType(PsBrandLoader), findsNothing);
    expect(find.text('Hello, Nadeeshi'), findsOneWidget);
  });

  testWidgets('A failed sign-in drops the loader and shows the error on the form', (tester) async {
    final (_, api, _) = await pumpApp(tester);
    api
      ..loginFails = true
      ..loginGate = Completer<void>();
    await tester.tap(find.text('Log in'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(0), 'me@example.com');
    await tester.enterText(find.byType(TextFormField).at(1), 'wrongpass1');
    await tester.tap(find.widgetWithText(InkWell, 'Log in').last);
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(PsBrandLoader), findsOneWidget);

    api.loginGate!.complete();
    await tester.pumpAndSettle();
    expect(find.byType(PsBrandLoader), findsNothing);
    expect(find.text('Incorrect phone, email or password'), findsOneWidget);
  });

  testWidgets('Skeletons announce "Loading" once and keep their bones silent', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_host(const SingleChildScrollView(child: PsSkeletonRows(count: 4))));
    expect(find.bySemanticsLabel('Loading'), findsOneWidget);
    expect(find.byType(PsBone), findsNWidgets(4 * 3));
    handle.dispose();
  });

  testWidgets('With reduced motion a skeleton holds still', (tester) async {
    await tester.pumpWidget(_host(const SingleChildScrollView(child: PsSkeletonDashboard()), reduceMotion: true));
    // Would time out if the shimmer were still running.
    await tester.pumpAndSettle();
    expect(find.byType(PsBone), findsWidgets);
  });

  testWidgets('Every skeleton lays out on a small phone without overflowing', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_host(const SingleChildScrollView(
      padding: EdgeInsets.all(20),
      child: Column(children: [
        PsSkeletonDashboard(),
        PsSkeletonRows(leading: PsSkeletonLeading.badge, trailing: true),
        PsSkeletonCard(lines: 4, button: true),
        PsSkeletonProfile(),
        SizedBox(height: 300, child: PsSkeletonChat()),
      ]),
    )));
    await tester.pump(const Duration(milliseconds: 700));
    expect(tester.takeException(), isNull);
  });
}

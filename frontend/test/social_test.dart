import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pay_and_save/core/social/social_models.dart';

import 'support/fakes.dart';
import 'support/pump.dart';

Future<void> openTab(WidgetTester tester, String label) async {
  await tester.tap(find.text(label).last);
  await tester.pumpAndSettle();
}

Future<void> tapText(WidgetTester tester, String text) async {
  await tester.ensureVisible(find.text(text).last);
  await tester.pumpAndSettle();
  await tester.tap(find.text(text).last);
  await tester.pumpAndSettle();
}

void main() {
  group('my profile', () {
    testWidgets('shows public counts and keeps private details labelled as private', (tester) async {
      await pumpApp(tester, signedIn: true);
      await openTab(tester, 'Profile');

      expect(find.text('12'), findsOneWidget);
      expect(find.text('Followers'), findsOneWidget);
      expect(find.text('Add a username'), findsOneWidget);
      expect(find.text('Private details'), findsOneWidget);
      expect(find.textContaining('Only you can see these'), findsOneWidget);
      expect(find.text('+9477*****21'), findsOneWidget);
    });

    testWidgets('edit profile sends only the changed fields and shows them', (tester) async {
      final (_, api, _) = await pumpApp(tester, signedIn: true);
      await openTab(tester, 'Profile');
      await tapText(tester, 'Edit profile');

      expect(find.textContaining('Email, password and NIC'), findsOneWidget);
      await tester.enterText(find.widgetWithText(TextFormField, 'e.g. nadeeshi.p'), '@Nadeeshi.P');
      await tester.enterText(find.widgetWithText(TextFormField, 'A line about you'), 'Saving for a sewing machine');
      await tapText(tester, 'Save changes');

      expect(api.lastProfilePatch, {'username': 'nadeeshi.p', 'bio': 'Saving for a sewing machine'});
      expect(find.text('Profile saved'), findsOneWidget);
      expect(find.text('@nadeeshi.p'), findsOneWidget);
      expect(find.text('Saving for a sewing machine'), findsOneWidget);
    });

    testWidgets('invalid username is caught on the device; taken one shows the server error', (tester) async {
      final (_, api, _) = await pumpApp(tester, signedIn: true);
      await openTab(tester, 'Profile');
      await tapText(tester, 'Edit profile');

      final field = find.widgetWithText(TextFormField, 'e.g. nadeeshi.p');
      await tester.enterText(field, 'ab');
      await tapText(tester, 'Save changes');
      expect(find.text('Use 3–30 letters, numbers, dots or underscores.'), findsOneWidget);
      expect(api.lastProfilePatch, isNull);

      await tester.enterText(field, 'taken');
      await tapText(tester, 'Save changes');
      expect(find.text('That username is taken.'), findsOneWidget);
      expect(find.text('Save changes'), findsOneWidget); // still on the edit screen
    });

    testWidgets('choosing a photo uploads it and confirms', (tester) async {
      final (_, api, _) = await pumpApp(tester, signedIn: true);
      await openTab(tester, 'Profile');

      await tester.tap(find.bySemanticsLabel('Change profile photo'));
      await tester.pumpAndSettle();
      expect(find.text('Take a photo'), findsOneWidget);
      expect(find.text('Remove photo'), findsNothing); // nothing to remove yet
      await tapText(tester, 'Choose from gallery');

      expect(api.uploadedAvatar, isNotNull);
      expect(api.current.avatarUrl, '/users/u1/avatar?v=1');
      expect(find.text('Profile photo updated'), findsOneWidget);
    });
  });

  group('people', () {
    testWidgets('Chats tab shows suggestions and conversations', (tester) async {
      await pumpApp(tester, signedIn: true);
      await openTab(tester, 'Chats');

      expect(find.text('Messages'), findsOneWidget);
      expect(find.text('Suggested for you'), findsOneWidget);
      expect(find.text('Ruwan Jayasuriya'), findsOneWidget);
      expect(find.text('In a circle with you'), findsOneWidget);
      expect(find.text('Kamala Silva'), findsOneWidget);
      expect(find.text('Did you pay this month?'), findsOneWidget);
    });

    testWidgets('search → profile shows only public facts, and Follow works', (tester) async {
      final social = FakeSocialApi();
      await pumpApp(tester, signedIn: true, social: social);
      await openTab(tester, 'Chats');

      await tester.enterText(find.byType(TextField).first, 'kam');
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
      expect(social.searches, ['kam']);
      await tester.tap(find.text('@kamala'));
      await tester.pumpAndSettle();

      expect(find.text('Kamala Silva'), findsOneWidget);
      expect(find.text("Saving for my daughter's school fees"), findsOneWidget);
      expect(find.text('Galle'), findsOneWidget);
      expect(find.text('Follows you'), findsOneWidget);
      expect(find.textContaining('never shown on profiles'), findsOneWidget);
      for (final private in ['+94', 'example.com', 'NIC:', '29']) {
        expect(find.textContaining(private), findsNothing);
      }

      await tapText(tester, 'Follow back');
      expect(social.followCalls, [('u2', true)]);
    });

    testWidgets('no results says so', (tester) async {
      await pumpApp(tester, signedIn: true);
      await openTab(tester, 'Chats');
      await tester.enterText(find.byType(TextField).first, 'zzz');
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
      expect(find.text('No one found for “zzz”'), findsOneWidget);
    });

    testWidgets('blocking asks first, then shows the blocked state', (tester) async {
      await pumpApp(tester, signedIn: true);
      await openTab(tester, 'Chats');
      await tester.tap(find.text('Kamala Silva'));
      await tester.pumpAndSettle();
      await tester.tap(find.bySemanticsLabel('Kamala Silva, View profile'));
      await tester.pumpAndSettle();

      await tester.tap(find.bySemanticsLabel('More actions'));
      await tester.pumpAndSettle();
      await tapText(tester, 'Block');
      expect(find.text('Block Kamala Silva?'), findsOneWidget);
      expect(find.textContaining("They won't be told"), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('Block Kamala Silva?'), findsNothing);
    });
  });

  group('chat', () {
    testWidgets('sends a message and shows it in the thread', (tester) async {
      final social = FakeSocialApi();
      await pumpApp(tester, signedIn: true, social: social);
      await openTab(tester, 'Chats');
      await tester.tap(find.text('Kamala Silva'));
      await tester.pumpAndSettle();

      expect(find.text('Did you pay this month?'), findsOneWidget);
      await tester.enterText(find.byType(TextField), '  Yes, cash on Sunday  ');
      await tester.pump();
      await tester.tap(find.bySemanticsLabel('Send'));
      await tester.pumpAndSettle();

      expect(find.text('Yes, cash on Sunday'), findsOneWidget);
      expect(social.messagesByChat['c1']!.last.body, 'Yes, cash on Sunday');
      expect(social.sentIds, hasLength(1));
    });

    testWidgets('a failed send can be retried with the same message id', (tester) async {
      final social = FakeSocialApi()..failNextSend = true;
      await pumpApp(tester, signedIn: true, social: social);
      await openTab(tester, 'Chats');
      await tester.tap(find.text('Kamala Silva'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'Hello');
      await tester.pump();
      await tester.tap(find.bySemanticsLabel('Send'));
      await tester.pumpAndSettle();
      expect(find.text('Not sent · Tap to retry'), findsOneWidget);

      await tester.tap(find.text('Hello'));
      await tester.pumpAndSettle();
      expect(find.text('Not sent · Tap to retry'), findsNothing);
      expect(social.sentIds, hasLength(2));
      expect(social.sentIds[0], social.sentIds[1]);
      expect(social.messagesByChat['c1']!.where((m) => m.body == 'Hello'), hasLength(1));
    });

    testWidgets('unread count shows on the Chats tab', (tester) async {
      await pumpApp(tester, signedIn: true, social: FakeSocialApi()..unread = 3);
      expect(tester.widgetList<Badge>(find.byType(Badge)).any((b) => b.isLabelVisible), isTrue);
      expect(find.descendant(of: find.byType(Badge), matching: find.text('3')), findsWidgets);
    });
  });

  group('pals', () {
    testWidgets('my profile shows Followers and Pals, plus the requests entry', (tester) async {
      await pumpApp(tester, signedIn: true, social: FakeSocialApi()..palStatus['u2'] = PalStatus.incoming);
      await openTab(tester, 'Profile');

      expect(find.text('Followers'), findsOneWidget);
      expect(find.text('Pals'), findsOneWidget);
      expect(find.text('Following'), findsNothing);
      expect(find.text('3'), findsWidgets); // 3 pals in the fake
      expect(find.text('Pal requests'), findsOneWidget);
      expect(find.text('1 waiting for you'), findsOneWidget);
    });

    testWidgets('a suggestion card sends a pal request and then shows Pending', (tester) async {
      final social = FakeSocialApi();
      await pumpApp(tester, signedIn: true, social: social);
      await openTab(tester, 'Chats');

      await tester.tap(find.text('Add pal'));
      await tester.pumpAndSettle();
      expect(social.palCalls, ['request:u3']);
      expect(find.text('Pal request sent'), findsOneWidget);
      expect(find.text('Pending'), findsOneWidget);
      expect(find.text('Ruwan Jayasuriya'), findsOneWidget); // card stays

      // tapping Pending offers to withdraw, and asks first
      await tester.tap(find.text('Pending'));
      await tester.pumpAndSettle();
      expect(find.text('Withdraw your pal request to Ruwan Jayasuriya?'), findsOneWidget);
      await tester.tap(find.widgetWithText(InkWell, 'Withdraw'));
      await tester.pumpAndSettle();
      expect(social.palCalls, ['request:u3', 'end:u3']);
      expect(find.text('Add pal'), findsOneWidget);
    });

    testWidgets('accepting an incoming request on their profile makes you pals', (tester) async {
      final social = FakeSocialApi()..palStatus['u2'] = PalStatus.incoming;
      await pumpApp(tester, signedIn: true, social: social);
      await openTab(tester, 'Chats');
      await tester.enterText(find.byType(TextField).first, 'kam');
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
      await tester.tap(find.text('@kamala'));
      await tester.pumpAndSettle();

      expect(find.text('Kamala Silva wants to be your pal'), findsOneWidget);
      expect(find.text('5'), findsOneWidget); // her pals before
      await tapText(tester, 'Accept');

      expect(social.palCalls, ['accept:u2']);
      expect(find.text('You and Kamala Silva are now pals'), findsOneWidget);
      expect(find.text('6'), findsOneWidget);
      expect(find.text('Pals'), findsWidgets); // stat label + button
      expect(find.text('Accept'), findsNothing);
    });

    testWidgets('requests screen: accept from Received, withdraw from Sent', (tester) async {
      final social = FakeSocialApi()
        ..palStatus['u2'] = PalStatus.incoming
        ..palStatus['u3'] = PalStatus.outgoing;
      await pumpApp(tester, signedIn: true, social: social);
      await openTab(tester, 'Chats');
      await tapText(tester, 'Pal requests');

      expect(find.text('Received (1)'), findsOneWidget);
      expect(find.text('Sent (1)'), findsOneWidget);
      expect(find.textContaining('2 mutual pals'), findsOneWidget);
      await tapText(tester, 'Accept');
      expect(social.palCalls, ['accept:u2']);
      expect(find.text('No pal requests right now.'), findsOneWidget);

      await tapText(tester, 'Sent (1)');
      expect(find.text('Ruwan Jayasuriya'), findsOneWidget);
      await tapText(tester, 'Withdraw');
      await tester.tap(find.widgetWithText(InkWell, 'Withdraw').last);
      await tester.pumpAndSettle();
      expect(social.palCalls, ['accept:u2', 'end:u3']);
      expect(find.text('You have no pending requests.'), findsOneWidget);
    });

    testWidgets('the Chats badge adds pal requests to unread messages', (tester) async {
      await pumpApp(
        tester,
        signedIn: true,
        social: FakeSocialApi()
          ..unread = 2
          ..palStatus['u2'] = PalStatus.incoming,
      );
      expect(find.descendant(of: find.byType(Badge), matching: find.text('3')), findsWidgets);
    });
  });
}

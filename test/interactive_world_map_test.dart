import 'package:auction_empire/features/map_properties/presentation/interactive_world_map.dart';
import 'package:auction_empire/game_state.dart';
import 'package:auction_empire/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _testApp(GameState game) => MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: InteractiveWorldMap(game: game, onManageHome: () {}),
      ),
    );

void main() {
  testWidgets('drills from a region into an accessible property interior',
      (tester) async {
    final game = GameState();
    await tester.pumpWidget(_testApp(game));

    await tester.tap(find.text('Northbank').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Aurelia City').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Starter Shed').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Enter property'));
    await tester.pumpAndSettle();

    expect(find.text('Starter Shed · Your home'), findsOneWidget);
    expect(find.text('Manage room'), findsOneWidget);

    await tester.tap(find.text('Exit'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Luna Lofts').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Enter property'));
    await tester.pumpAndSettle();

    expect(find.text('Luna Lofts · Guest view'), findsOneWidget);
    expect(find.text('Sculpture'), findsOneWidget);

    game.dispose();
  });

  testWidgets('lets owners gate access to another property', (tester) async {
    final game = GameState();
    await tester.pumpWidget(_testApp(game));

    await tester.tap(find.text('Northbank').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Aurelia City').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Willow Villa').first);
    await tester.pumpAndSettle();
    expect(find.text('Request access'), findsOneWidget);

    await tester.tap(find.text('Request access'));
    await tester.pumpAndSettle();

    expect(find.text('Access requested'), findsOneWidget);
    expect(find.text('Waiting for the owner to approve your visit'), findsOneWidget);
    game.dispose();
  });
}

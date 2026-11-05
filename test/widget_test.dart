import 'package:auction_empire/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('switches the app UI to Hebrew', (tester) async {
    await tester.pumpWidget(const AuctionEmpireApp());

    expect(find.text('World'), findsNWidgets(2));

    await tester.tap(find.text('Profile').last);
    await tester.pump();
    final localeDropdown = find.byType(DropdownButton<Locale>);
    await tester.ensureVisible(localeDropdown);
    await tester.tap(localeDropdown);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('עברית').last);
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.text('מפה').last);
    await tester.pump();

    expect(find.text('האימפריה שלך מתחילה כאן'), findsOneWidget);
  });
}

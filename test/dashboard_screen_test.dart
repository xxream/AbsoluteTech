import 'package:flutter/material.dart';
import 'package:absolute_tech/features/dashboard/dashboard_screen.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows dashboard and changes the selected time range',
      (tester) async {
    await tester.pumpWidget(const TestApp());

    expect(find.text('Your health, at a glance'), findsOneWidget);
    expect(find.text('Week'), findsOneWidget);

    await tester.tap(find.text('Month'));
    await tester.pumpAndSettle();

    expect(find.text('30-day average'), findsWidgets);
  });
}

class TestApp extends StatelessWidget {
  const TestApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(home: DashboardScreen());
  }
}

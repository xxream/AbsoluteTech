import 'package:absolute_tech/data/health_data_repository.dart';
import 'package:absolute_tech/features/dashboard/dashboard_screen.dart';
import 'package:absolute_tech/models/daily_health_summary.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows connected health data and changes time range', (
    tester,
  ) async {
    await tester.pumpWidget(
      TestApp(repository: FakeHealthDataRepository.withRecordedData()),
    );
    await tester.pumpAndSettle();

    expect(find.text('Your health, at a glance'), findsOneWidget);
    expect(find.text('Health Connect is connected'), findsOneWidget);
    expect(find.text('Week'), findsOneWidget);
    expect(find.text('7500'), findsOneWidget);

    await tester.tap(find.text('Month'));
    await tester.pumpAndSettle();

    expect(find.text('30-day average'), findsWidgets);
  });

  testWidgets('shows missing readings instead of fabricated values', (
    tester,
  ) async {
    await tester.pumpWidget(
      TestApp(repository: FakeHealthDataRepository.withoutReadings()),
    );
    await tester.pumpAndSettle();

    expect(find.text('--'), findsNWidgets(3));
    expect(find.text('No recorded data'), findsNWidgets(3));
  });
}

class TestApp extends StatelessWidget {
  const TestApp({required this.repository, super.key});

  final HealthDataRepository repository;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(home: DashboardScreen(repository: repository));
  }
}

class FakeHealthDataRepository implements HealthDataRepository {
  FakeHealthDataRepository(this._access, this._days);

  factory FakeHealthDataRepository.withRecordedData() {
    final today = DateTime.now();
    final days = List.generate(30, (index) {
      final date = DateTime(
        today.year,
        today.month,
        today.day,
      ).subtract(Duration(days: 29 - index));
      final isActiveDay = index.isEven;
      return DailyHealthSummary(
        date: date,
        steps: isActiveDay ? 9000 : 6000,
        sleepMinutes: isActiveDay ? 450 : 410,
        restingHeartRate: isActiveDay ? 60 : 62,
      );
    });

    return FakeHealthDataRepository(
      const HealthAccessStatus(
        platform: HealthPlatform.android,
        providerAvailable: true,
        stepsAuthorized: true,
        sleepAuthorized: true,
        restingHeartRateAuthorized: true,
        activityRecognitionGranted: true,
      ),
      days,
    );
  }

  factory FakeHealthDataRepository.withoutReadings() {
    final today = DateTime.now();
    final days = List.generate(
      30,
      (index) => DailyHealthSummary(
        date: DateTime(
          today.year,
          today.month,
          today.day,
        ).subtract(Duration(days: 29 - index)),
        steps: null,
        sleepMinutes: null,
        restingHeartRate: null,
      ),
    );

    return FakeHealthDataRepository(
      const HealthAccessStatus(
        platform: HealthPlatform.android,
        providerAvailable: true,
        stepsAuthorized: true,
        sleepAuthorized: true,
        restingHeartRateAuthorized: true,
        activityRecognitionGranted: true,
      ),
      days,
    );
  }

  final HealthAccessStatus _access;
  final List<DailyHealthSummary> _days;

  @override
  Future<HealthAccessStatus> checkAccess() async => _access;

  @override
  Future<void> installHealthConnect() async {}

  @override
  Future<List<DailyHealthSummary>> loadRecentSummaries(
    HealthAccessStatus access, {
    int days = 30,
  }) async => _days;

  @override
  Future<HealthAccessStatus> requestAccess() async => _access;
}

import 'package:flutter_test/flutter_test.dart';

import 'package:absolute_tech/features/insights/insight_analyzer.dart';
import 'package:absolute_tech/models/daily_health_summary.dart';

void main() {
  const analyzer = InsightAnalyzer();

  List<DailyHealthSummary> cohortData({
    required int highStepDays,
    required int lowStepDays,
    required int highSleepMinutes,
    required int lowSleepMinutes,
  }) {
    return [
      for (var index = 0; index < highStepDays; index++)
        DailyHealthSummary(
          date: DateTime(2026, 1, index + 1),
          steps: 9000,
          sleepMinutes: highSleepMinutes,
          restingHeartRate: 60,
        ),
      for (var index = 0; index < lowStepDays; index++)
        DailyHealthSummary(
          date: DateTime(2026, 2, index + 1),
          steps: 6000,
          sleepMinutes: lowSleepMinutes,
          restingHeartRate: 62,
        ),
    ];
  }

  test('suppresses insight when either cohort has fewer than five days', () {
    final result = analyzer.compareSleepByStepCount(
      cohortData(
        highStepDays: 4,
        lowStepDays: 8,
        highSleepMinutes: 450,
        lowSleepMinutes: 400,
      ),
    );

    expect(result, isNull);
  });

  test('returns a descriptive insight with both cohort sizes', () {
    final result = analyzer.compareSleepByStepCount(
      cohortData(
        highStepDays: 6,
        lowStepDays: 7,
        highSleepMinutes: 450,
        lowSleepMinutes: 410,
      ),
    );

    expect(result, isNotNull);
    expect(result!.sampleSize, 13);
    expect(result.description, contains('6 recorded days'));
    expect(result.description, contains('7 other days'));
    expect(result.description, contains('40 minutes longer'));
    expect(result.description, contains('not evidence that steps caused'));
  });

  test('suppresses differences below the practical threshold', () {
    final result = analyzer.compareSleepByStepCount(
      cohortData(
        highStepDays: 6,
        lowStepDays: 6,
        highSleepMinutes: 420,
        lowSleepMinutes: 405,
      ),
    );

    expect(result, isNull);
  });
}

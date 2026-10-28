import '../../models/daily_health_summary.dart';

class HealthInsight {
  const HealthInsight({
    required this.title,
    required this.description,
    required this.sampleSize,
  });

  final String title;
  final String description;
  final int sampleSize;
}

class InsightAnalyzer {
  const InsightAnalyzer();

  HealthInsight? compareSleepByStepCount(
    List<DailyHealthSummary> days, {
    int stepThreshold = 8000,
    int minimumDaysPerCohort = 5,
  }) {
    final comparableDays = days
        .where((day) => day.steps != null && day.sleepMinutes != null)
        .toList();
    final activeDays = comparableDays
        .where((day) => day.steps! >= stepThreshold)
        .toList();
    final otherDays = comparableDays
        .where((day) => day.steps! < stepThreshold)
        .toList();

    if (activeDays.length < minimumDaysPerCohort ||
        otherDays.length < minimumDaysPerCohort) {
      return null;
    }

    final activeAverage = _averageSleep(activeDays);
    final otherAverage = _averageSleep(otherDays);
    final difference = activeAverage - otherAverage;
    if (difference.abs() < 20) {
      return null;
    }

    final longer = difference > 0;
    final minutes = difference.abs().round();
    final direction = longer ? 'longer' : 'shorter';
    final description =
        'Across ${activeDays.length} recorded days with at least '
        '$stepThreshold steps and ${otherDays.length} other days, '
        'sleep averaged $minutes minutes $direction in the higher-step group. '
        'This is a personal comparison, not evidence that steps caused the difference.';

    return HealthInsight(
      title: 'Sleep on higher-step days',
      description: description,
      sampleSize: comparableDays.length,
    );
  }

  double _averageSleep(List<DailyHealthSummary> days) {
    return days.fold<int>(0, (total, day) => total + day.sleepMinutes!) /
        days.length;
  }
}

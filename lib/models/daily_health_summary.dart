class DailyHealthSummary {
  const DailyHealthSummary({
    required this.date,
    required this.steps,
    required this.sleepMinutes,
    required this.restingHeartRate,
  });

  final DateTime date;
  final int? steps;
  final int? sleepMinutes;
  final double? restingHeartRate;
}

import '../models/daily_health_summary.dart';

class DemoHealthData {
  static final List<DailyHealthSummary> days = List.generate(30, (index) {
    final dayOffset = 29 - index;
    final date = DateTime.now().subtract(Duration(days: dayOffset));
    final steps = 5200 + ((index * 1783 + 1297) % 7200);
    final sleepMinutes = 365 + ((index * 37 + 23) % 115);

    return DailyHealthSummary(
      date: DateTime(date.year, date.month, date.day),
      steps: steps,
      sleepMinutes: sleepMinutes,
      restingHeartRate: 58 + ((index * 7 + 4) % 18),
    );
  });
}

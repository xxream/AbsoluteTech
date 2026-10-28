import '../models/daily_health_summary.dart';
import 'demo_health_data.dart';

abstract interface class HealthDataRepository {
  List<DailyHealthSummary> loadRecentSummaries();
}

class DemoHealthDataRepository implements HealthDataRepository {
  const DemoHealthDataRepository();

  @override
  List<DailyHealthSummary> loadRecentSummaries() =>
      List.unmodifiable(DemoHealthData.days);
}

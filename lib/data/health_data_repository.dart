import 'dart:io';

import 'package:health/health.dart';
import 'package:permission_handler/permission_handler.dart';

import '../models/daily_health_summary.dart';

enum HealthPlatform { android, ios, unsupported }

class HealthAccessStatus {
  const HealthAccessStatus({
    required this.platform,
    required this.providerAvailable,
    required this.stepsAuthorized,
    required this.sleepAuthorized,
    required this.restingHeartRateAuthorized,
    required this.activityRecognitionGranted,
    this.requiresHealthConnectInstall = false,
  });

  final HealthPlatform platform;
  final bool providerAvailable;
  final bool? stepsAuthorized;
  final bool? sleepAuthorized;
  final bool? restingHeartRateAuthorized;
  final bool activityRecognitionGranted;
  final bool requiresHealthConnectInstall;

  bool get hasAnyAndroidPermission =>
      stepsAuthorized == true ||
      sleepAuthorized == true ||
      restingHeartRateAuthorized == true;

  String get platformName => switch (platform) {
    HealthPlatform.android => 'Health Connect',
    HealthPlatform.ios => 'Apple Health',
    HealthPlatform.unsupported => 'Health data',
  };
}

abstract interface class HealthDataRepository {
  Future<HealthAccessStatus> checkAccess();

  Future<HealthAccessStatus> requestAccess();

  Future<void> installHealthConnect();

  Future<List<DailyHealthSummary>> loadRecentSummaries(
    HealthAccessStatus access, {
    int days = 30,
  });
}

class PlatformHealthDataRepository implements HealthDataRepository {
  PlatformHealthDataRepository({Health? health}) : _health = health ?? Health();

  static const _readTypes = [
    HealthDataType.STEPS,
    HealthDataType.SLEEP_ASLEEP,
    HealthDataType.RESTING_HEART_RATE,
  ];

  final Health _health;
  Future<void>? _configuration;

  HealthPlatform get _platform {
    if (Platform.isAndroid) return HealthPlatform.android;
    if (Platform.isIOS) return HealthPlatform.ios;
    return HealthPlatform.unsupported;
  }

  Future<void> _ensureConfigured() => _configuration ??= _health.configure();

  @override
  Future<HealthAccessStatus> checkAccess() async {
    await _ensureConfigured();

    final platform = _platform;
    if (platform == HealthPlatform.unsupported) {
      return const HealthAccessStatus(
        platform: HealthPlatform.unsupported,
        providerAvailable: false,
        stepsAuthorized: false,
        sleepAuthorized: false,
        restingHeartRateAuthorized: false,
        activityRecognitionGranted: false,
      );
    }

    if (platform == HealthPlatform.android) {
      final status = await _health.getHealthConnectSdkStatus();
      if (status != HealthConnectSdkStatus.sdkAvailable) {
        return HealthAccessStatus(
          platform: platform,
          providerAvailable: false,
          stepsAuthorized: false,
          sleepAuthorized: false,
          restingHeartRateAuthorized: false,
          activityRecognitionGranted: false,
          requiresHealthConnectInstall: true,
        );
      }

      final activityRecognition = await Permission.activityRecognition.status;
      final permissions = await Future.wait(
        _readTypes.map((type) => _health.hasPermissions([type])),
      );

      return HealthAccessStatus(
        platform: platform,
        providerAvailable: true,
        stepsAuthorized: permissions[0] ?? false,
        sleepAuthorized: permissions[1] ?? false,
        restingHeartRateAuthorized: permissions[2] ?? false,
        activityRecognitionGranted: activityRecognition.isGranted,
      );
    }

    final permissions = await Future.wait(
      _readTypes.map((type) => _health.hasPermissions([type])),
    );
    return HealthAccessStatus(
      platform: platform,
      providerAvailable: true,
      stepsAuthorized: permissions[0],
      sleepAuthorized: permissions[1],
      restingHeartRateAuthorized: permissions[2],
      activityRecognitionGranted: true,
    );
  }

  @override
  Future<HealthAccessStatus> requestAccess() async {
    await _ensureConfigured();

    if (_platform == HealthPlatform.unsupported) {
      return checkAccess();
    }

    final initial = await checkAccess();
    if (!initial.providerAvailable) return initial;

    if (_platform == HealthPlatform.android) {
      await Permission.activityRecognition.request();
    }

    await _health.requestAuthorization(_readTypes);
    return checkAccess();
  }

  @override
  Future<void> installHealthConnect() async {
    await _ensureConfigured();
    await _health.installHealthConnect();
  }

  @override
  Future<List<DailyHealthSummary>> loadRecentSummaries(
    HealthAccessStatus access, {
    int days = 30,
  }) async {
    if (!access.providerAvailable) return const [];

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final firstDay = today.subtract(Duration(days: days - 1));
    final dates = List.generate(
      days,
      (index) => firstDay.add(Duration(days: index)),
    );
    final summaries = {
      for (final date in dates)
        date: DailyHealthSummary(
          date: date,
          steps: null,
          sleepMinutes: null,
          restingHeartRate: null,
        ),
    };

    final canReadSteps =
        access.platform == HealthPlatform.ios ||
        (access.stepsAuthorized == true && access.activityRecognitionGranted);
    final canReadSleep =
        access.platform == HealthPlatform.ios || access.sleepAuthorized == true;
    final canReadRestingHeartRate =
        access.platform == HealthPlatform.ios ||
        access.restingHeartRateAuthorized == true;

    if (canReadSteps) {
      for (final date in dates) {
        final end = date == today ? now : date.add(const Duration(days: 1));
        final steps = await _health.getTotalStepsInInterval(date, end);
        summaries[date] = _copySummary(summaries[date]!, steps: steps);
      }
    }

    if (canReadSleep) {
      final sleepPoints = await _health.getHealthDataFromTypes(
        types: const [HealthDataType.SLEEP_ASLEEP],
        startTime: firstDay,
        endTime: now,
      );
      final intervalsByDate = <DateTime, List<(DateTime, DateTime)>>{};
      for (final point in sleepPoints) {
        final sleepStart = point.dateFrom.isBefore(firstDay)
            ? firstDay
            : point.dateFrom;
        final sleepEnd = point.dateTo.isAfter(now) ? now : point.dateTo;
        var cursor = sleepStart;

        while (cursor.isBefore(sleepEnd)) {
          final day = DateTime(cursor.year, cursor.month, cursor.day);
          final nextDay = day.add(const Duration(days: 1));
          final segmentEnd = sleepEnd.isBefore(nextDay) ? sleepEnd : nextDay;
          if (segmentEnd.isAfter(cursor) && summaries.containsKey(day)) {
            intervalsByDate.putIfAbsent(day, () => []).add((
              cursor,
              segmentEnd,
            ));
          }
          cursor = segmentEnd;
        }
      }

      for (final entry in intervalsByDate.entries) {
        final intervals = entry.value
          ..sort((first, second) => first.$1.compareTo(second.$1));
        var mergedStart = intervals.first.$1;
        var mergedEnd = intervals.first.$2;
        var total = Duration.zero;

        for (final interval in intervals.skip(1)) {
          if (interval.$1.isAfter(mergedEnd)) {
            total += mergedEnd.difference(mergedStart);
            mergedStart = interval.$1;
            mergedEnd = interval.$2;
          } else if (interval.$2.isAfter(mergedEnd)) {
            mergedEnd = interval.$2;
          }
        }
        total += mergedEnd.difference(mergedStart);

        summaries[entry.key] = _copySummary(
          summaries[entry.key]!,
          sleepMinutes: total.inMinutes,
        );
      }
    }

    if (canReadRestingHeartRate) {
      final heartRatePoints = await _health.getHealthDataFromTypes(
        types: const [HealthDataType.RESTING_HEART_RATE],
        startTime: firstDay,
        endTime: now,
      );
      final readingsByDate = <DateTime, List<double>>{};
      for (final point in heartRatePoints) {
        if (point.value case NumericHealthValue(:final numericValue)) {
          final date = DateTime(
            point.dateTo.year,
            point.dateTo.month,
            point.dateTo.day,
          );
          readingsByDate
              .putIfAbsent(date, () => [])
              .add(numericValue.toDouble());
        }
      }

      for (final entry in readingsByDate.entries) {
        final existing = summaries[entry.key];
        if (existing != null && entry.value.isNotEmpty) {
          final mean = entry.value.reduce((a, b) => a + b) / entry.value.length;
          summaries[entry.key] = _copySummary(existing, restingHeartRate: mean);
        }
      }
    }

    return dates.map((date) => summaries[date]!).toList(growable: false);
  }

  DailyHealthSummary _copySummary(
    DailyHealthSummary summary, {
    int? steps,
    int? sleepMinutes,
    double? restingHeartRate,
  }) {
    return DailyHealthSummary(
      date: summary.date,
      steps: steps ?? summary.steps,
      sleepMinutes: sleepMinutes ?? summary.sleepMinutes,
      restingHeartRate: restingHeartRate ?? summary.restingHeartRate,
    );
  }
}

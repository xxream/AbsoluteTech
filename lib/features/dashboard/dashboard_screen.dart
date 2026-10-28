import 'package:flutter/material.dart';

import '../../data/health_data_repository.dart';
import '../../models/daily_health_summary.dart';
import '../insights/insight_analyzer.dart';

enum DashboardRange { day, week, month }

class DashboardScreen extends StatefulWidget {
  DashboardScreen({super.key, HealthDataRepository? repository})
    : repository = repository ?? PlatformHealthDataRepository();

  final HealthDataRepository repository;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  DashboardRange _range = DashboardRange.week;
  HealthAccessStatus? _access;
  List<DailyHealthSummary> _allDays = const [];
  bool _loading = true;
  bool _authorizationRequested = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh({
    bool requestAccess = false,
    bool installHealthConnect = false,
  }) async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      if (installHealthConnect) {
        await widget.repository.installHealthConnect();
      }

      final access = requestAccess
          ? await widget.repository.requestAccess()
          : await widget.repository.checkAccess();
      final days = access.providerAvailable
          ? await widget.repository.loadRecentSummaries(access)
          : const <DailyHealthSummary>[];

      if (!mounted) return;
      setState(() {
        _access = access;
        _allDays = days;
        _authorizationRequested |= requestAccess;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not read health data: $error';
        _loading = false;
      });
    }
  }

  List<DailyHealthSummary> get _visibleDays {
    final count = switch (_range) {
      DashboardRange.day => 1,
      DashboardRange.week => 7,
      DashboardRange.month => 30,
    };
    return _allDays.reversed.take(count).toList().reversed.toList();
  }

  @override
  Widget build(BuildContext context) {
    final days = _visibleDays;
    final steps = _average(days.map((day) => day.steps).whereType<int>());
    final sleep = _average(
      days.map((day) => day.sleepMinutes).whereType<int>(),
    );
    final latestHeartRate = days.reversed
        .map((day) => day.restingHeartRate)
        .whereType<double>()
        .firstOrNull;
    final insight = const InsightAnalyzer().compareSleepByStepCount(_allDays);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Health Insights'),
        actions: [
          IconButton(
            tooltip: 'Refresh health data',
            onPressed: _loading ? null : () => _refresh(),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          children: [
            Text(
              'Your health, at a glance',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              'Your records, read directly from your health app.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 18),
            _ConnectionCard(
              access: _access,
              days: _allDays,
              loading: _loading,
              authorizationRequested: _authorizationRequested,
              onConnect: () => _refresh(requestAccess: true),
              onInstallHealthConnect: () =>
                  _refresh(installHealthConnect: true),
            ),
            if (_error case final error?) ...[
              const SizedBox(height: 12),
              _ErrorCard(message: error),
            ],
            const SizedBox(height: 20),
            _RangeSelector(
              value: _range,
              onChanged: (range) => setState(() => _range = range),
            ),
            const SizedBox(height: 16),
            _ActivityCard(
              averageSteps: steps,
              targetSteps: 10000,
              days: days,
              rangeLabel: _rangeLabel(_range),
              caption: _metricCaption(
                access: _access,
                permission: _access?.stepsAuthorized,
                hasData: steps != null,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _MetricCard(
                    icon: Icons.bedtime_outlined,
                    label: 'Average sleep',
                    value: sleep == null ? '--' : _formatDuration(sleep),
                    caption: _metricCaption(
                      access: _access,
                      permission: _access?.sleepAuthorized,
                      hasData: sleep != null,
                    ),
                    color: const Color(0xFF6250A4),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _MetricCard(
                    icon: Icons.favorite_border,
                    label: 'Resting heart rate',
                    value: latestHeartRate == null
                        ? '--'
                        : '${latestHeartRate.round()} bpm',
                    caption: _metricCaption(
                      access: _access,
                      permission: _access?.restingHeartRateAuthorized,
                      hasData: latestHeartRate != null,
                    ),
                    color: const Color(0xFFB84450),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              'Patterns',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            if (insight case final insight?)
              _InsightCard(insight: insight)
            else
              const _EmptyInsightCard(),
            const SizedBox(height: 16),
            const _PrivacyNote(),
          ],
        ),
      ),
    );
  }

  static int? _average(Iterable<int> values) {
    final list = values.toList();
    if (list.isEmpty) return null;
    return list.reduce((first, second) => first + second) ~/ list.length;
  }

  String _metricCaption({
    required HealthAccessStatus? access,
    required bool? permission,
    required bool hasData,
  }) {
    if (hasData) return _rangeLabel(_range);
    if (_loading) return 'Loading health data';
    if (access == null) return 'Connect a health app';
    if (!access.providerAvailable) return 'Health app unavailable';
    if (access.platform == HealthPlatform.android && permission == false) {
      return 'Permission not granted';
    }
    if (access.platform == HealthPlatform.ios) {
      return 'No data shared with this app';
    }
    return 'No recorded data';
  }

  static String _formatDuration(int minutes) {
    final hours = minutes ~/ 60;
    final remainingMinutes = minutes % 60;
    return '${hours}h ${remainingMinutes}m';
  }

  static String _rangeLabel(DashboardRange range) => switch (range) {
    DashboardRange.day => 'Today',
    DashboardRange.week => '7-day average',
    DashboardRange.month => '30-day average',
  };
}

class _ConnectionCard extends StatelessWidget {
  const _ConnectionCard({
    required this.access,
    required this.days,
    required this.loading,
    required this.authorizationRequested,
    required this.onConnect,
    required this.onInstallHealthConnect,
  });

  final HealthAccessStatus? access;
  final List<DailyHealthSummary> days;
  final bool loading;
  final bool authorizationRequested;
  final VoidCallback onConnect;
  final VoidCallback onInstallHealthConnect;

  bool get _hasData => days.any(
    (day) =>
        day.steps != null ||
        day.sleepMinutes != null ||
        day.restingHeartRate != null,
  );

  String get _title {
    if (access == null) return 'Checking health data access';
    if (!access!.providerAvailable) {
      return access!.platform == HealthPlatform.android
          ? 'Health Connect is unavailable'
          : 'Health data is unavailable';
    }
    if (access!.platform == HealthPlatform.ios) {
      if (_hasData) return 'Apple Health data is available';
      return authorizationRequested
          ? 'Apple Health access was requested'
          : 'Connect Apple Health';
    }
    if (access!.hasAnyAndroidPermission) return 'Health Connect is connected';
    return 'Connect Health Connect';
  }

  String get _description {
    if (access == null) return 'Checking permissions on this device.';
    if (!access!.providerAvailable) {
      return 'Install or update Health Connect, then try connecting again.';
    }
    if (access!.platform == HealthPlatform.ios) {
      if (_hasData) {
        return 'These records are read directly from Apple Health on this device.';
      }
      if (authorizationRequested) {
        return 'Apple does not tell apps whether read access was denied. '
            'If no values appear, enable Steps, Sleep, and Heart Rate for '
            'Health Insights in iPhone Settings > Health.';
      }
      return 'Choose which Steps, Sleep, and Resting Heart Rate records '
          'Health Insights may read.';
    }
    if (!access!.hasAnyAndroidPermission) {
      return 'Choose which Steps, Sleep, and Resting Heart Rate records '
          'Health Insights may read.';
    }
    if (access!.stepsAuthorized == true &&
        !access!.activityRecognitionGranted) {
      return 'Activity recognition is disabled. Steps may be unavailable; '
          'other granted health data can still appear.';
    }
    return 'Records are read from Health Connect on this device. '
        'Only metrics you allow are shown.';
  }

  String get _buttonLabel {
    if (access?.platform == HealthPlatform.android &&
        access?.providerAvailable == false) {
      return 'Install or update Health Connect';
    }
    if (access?.platform == HealthPlatform.ios) {
      return authorizationRequested
          ? 'Refresh health data'
          : 'Connect Apple Health';
    }
    if (access?.hasAnyAndroidPermission == true) {
      return 'Refresh health data';
    }
    return 'Connect Health Connect';
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      color: colorScheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.health_and_safety_outlined,
                  color: colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (loading)
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(_description),
            if (access?.providerAvailable != false ||
                access?.platform == HealthPlatform.android) ...[
              const SizedBox(height: 12),
              FilledButton.tonal(
                onPressed: loading
                    ? null
                    : access?.platform == HealthPlatform.android &&
                          access?.providerAvailable == false
                    ? onInstallHealthConnect
                    : onConnect,
                child: Text(_buttonLabel),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.errorContainer,
      child: Padding(padding: const EdgeInsets.all(14), child: Text(message)),
    );
  }
}

class _RangeSelector extends StatelessWidget {
  const _RangeSelector({required this.value, required this.onChanged});

  final DashboardRange value;
  final ValueChanged<DashboardRange> onChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<DashboardRange>(
      segments: const [
        ButtonSegment(value: DashboardRange.day, label: Text('Day')),
        ButtonSegment(value: DashboardRange.week, label: Text('Week')),
        ButtonSegment(value: DashboardRange.month, label: Text('Month')),
      ],
      selected: {value},
      onSelectionChanged: (selection) => onChanged(selection.first),
    );
  }
}

class _ActivityCard extends StatelessWidget {
  const _ActivityCard({
    required this.averageSteps,
    required this.targetSteps,
    required this.days,
    required this.rangeLabel,
    required this.caption,
  });

  final int? averageSteps;
  final int targetSteps;
  final List<DailyHealthSummary> days;
  final String rangeLabel;
  final String caption;

  @override
  Widget build(BuildContext context) {
    final progress = averageSteps == null
        ? 0.0
        : (averageSteps! / targetSteps).clamp(0.0, 1.0);
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.directions_walk, color: colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Steps',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                Text(rangeLabel),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              averageSteps?.toString() ?? '--',
              style: Theme.of(
                context,
              ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              averageSteps == null
                  ? caption
                  : 'Average per day · goal $targetSteps · $caption',
            ),
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 9,
                backgroundColor: colorScheme.primary.withValues(alpha: 0.12),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(height: 72, child: _StepsBars(days: days)),
          ],
        ),
      ),
    );
  }
}

class _StepsBars extends StatelessWidget {
  const _StepsBars({required this.days});

  final List<DailyHealthSummary> days;

  @override
  Widget build(BuildContext context) {
    final maxSteps = days
        .map((day) => day.steps ?? 0)
        .fold<int>(1, (maximum, steps) => steps > maximum ? steps : maximum);
    final color = Theme.of(context).colorScheme.primary;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (final (index, day) in days.indexed)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: Tooltip(
                message: day.steps == null
                    ? 'No step data for day ${index + 1}'
                    : '${day.steps} steps',
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: day.steps == null
                        ? color.withValues(alpha: 0.12)
                        : color.withValues(
                            alpha: day.steps! / maxSteps < 0.5 ? 0.35 : 0.8,
                          ),
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(4),
                    ),
                  ),
                  child: SizedBox(
                    height: day.steps == null
                        ? 2
                        : 16 + (day.steps! / maxSteps * 50),
                    child: Semantics(
                      label: day.steps == null
                          ? 'No step data for day ${index + 1}'
                          : 'Day ${index + 1}: ${day.steps} steps',
                      child: const SizedBox.expand(),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.caption,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final String caption;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color),
            const SizedBox(height: 10),
            Text(label, style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 4),
            FittedBox(
              alignment: Alignment.centerLeft,
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              caption,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InsightCard extends StatelessWidget {
  const _InsightCard({required this.insight});

  final HealthInsight insight;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.auto_awesome_outlined,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    insight.title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(insight.description),
            const SizedBox(height: 8),
            Text(
              '${insight.sampleSize} days included · Descriptive comparison',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyInsightCard extends StatelessWidget {
  const _EmptyInsightCard();

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(18),
        child: Text(
          'More recorded days with both steps and sleep data are needed '
          'before a pattern can be compared.',
        ),
      ),
    );
  }
}

class _PrivacyNote extends StatelessWidget {
  const _PrivacyNote();

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: const Padding(
        padding: EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.lock_outline),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Health records are read from the platform health app. '
                'This prototype does not upload or persist them.',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

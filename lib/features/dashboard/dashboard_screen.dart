import 'package:flutter/material.dart';

import '../../data/health_data_repository.dart';
import '../../models/daily_health_summary.dart';
import '../insights/insight_analyzer.dart';

enum DashboardRange { day, week, month }

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({
    super.key,
    this.repository = const DemoHealthDataRepository(),
  });

  final HealthDataRepository repository;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  DashboardRange _range = DashboardRange.week;

  List<DailyHealthSummary> _visibleDays(List<DailyHealthSummary> allDays) {
    final count = switch (_range) {
      DashboardRange.day => 1,
      DashboardRange.week => 7,
      DashboardRange.month => 30,
    };
    return allDays.reversed.take(count).toList().reversed.toList();
  }

  @override
  Widget build(BuildContext context) {
    final allDays = widget.repository.loadRecentSummaries();
    if (allDays.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Health Insights')),
        body: const Center(
          child: Text('No health data is available for this view yet.'),
        ),
      );
    }

    final days = _visibleDays(allDays);
    final latest = allDays.last;
    final averageSteps =
        days.fold<int>(0, (sum, day) => sum + day.steps) ~/ days.length;
    final averageSleep =
        days.fold<int>(0, (sum, day) => sum + day.sleepMinutes) ~/ days.length;
    final insight = const InsightAnalyzer().compareSleepByStepCount(allDays);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Health Insights'),
        actions: [
          IconButton(
            tooltip: 'Data sources',
            onPressed: () => _showDemoNotice(context),
            icon: const Icon(Icons.health_and_safety_outlined),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          children: [
            Text(
              'Your health, at a glance',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              'A private view of your recorded activity and rest.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 20),
            _RangeSelector(
              value: _range,
              onChanged: (range) => setState(() => _range = range),
            ),
            const SizedBox(height: 16),
            _ActivityCard(
              averageSteps: averageSteps,
              targetSteps: 10000,
              days: days,
              rangeLabel: _rangeLabel(_range),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _MetricCard(
                    icon: Icons.bedtime_outlined,
                    label: 'Average sleep',
                    value: _formatDuration(averageSleep),
                    caption: _rangeLabel(_range),
                    color: const Color(0xFF6250A4),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _MetricCard(
                    icon: Icons.favorite_border,
                    label: 'Resting heart rate',
                    value: '${latest.restingHeartRate} bpm',
                    caption: 'Latest recorded',
                    color: const Color(0xFFB84450),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              'Patterns',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 10),
            if (insight case final insight?)
              _InsightCard(insight: insight)
            else
              const _EmptyInsightCard(),
            const SizedBox(height: 16),
            const _DemoDataBanner(),
          ],
        ),
      ),
    );
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

  static void _showDemoNotice(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content:
            Text('Health Connect and HealthKit setup is not connected yet.'),
      ),
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
  });

  final int averageSteps;
  final int targetSteps;
  final List<DailyHealthSummary> days;
  final String rangeLabel;

  @override
  Widget build(BuildContext context) {
    final progress = (averageSteps / targetSteps).clamp(0.0, 1.0);
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
              averageSteps.toString(),
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 4),
            Text('Average per day · goal $targetSteps'),
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
            SizedBox(
              height: 72,
              child: _StepsBars(days: days),
            ),
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
        .map((day) => day.steps)
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
                message: '${day.steps} steps',
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: color.withValues(
                      alpha: day.steps / maxSteps < 0.5 ? 0.35 : 0.8,
                    ),
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(4),
                    ),
                  ),
                  child: SizedBox(
                    height: 16 + (day.steps / maxSteps * 50),
                    child: Semantics(
                      label: 'Day ${index + 1}: ${day.steps} steps',
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
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
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
          'More recorded days are needed before a pattern can be compared.',
        ),
      ),
    );
  }
}

class _DemoDataBanner extends StatelessWidget {
  const _DemoDataBanner();

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.secondaryContainer,
      child: const Padding(
        padding: EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.science_outlined),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Prototype data only. No health records are read or stored. '
                'Connect Health Connect or HealthKit in a later milestone.',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

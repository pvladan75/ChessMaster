import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'package:chess_app/models/user_session.dart';
import 'package:chess_app/services/billing_service.dart';
import 'package:chess_app/services/usage_service.dart';
import 'package:chess_app/theme/app_colors.dart';
import 'package:chess_app/theme/app_typography.dart';

/// What the account has used this month, and where its plan draws the line.
///
/// Opened from Settings → Account → „Usage this month". The numbers are the
/// server's, counted for the account on every device, and start again on the
/// first of each month. What any of it costs us is not shown: the server does
/// not send it, and this screen would not draw it if it did.
///
/// Written 26.9.2026 while the app has one user, so that the month of
/// measuring the pricing doc asks for (docs/CENA-I-PRETPLATA.md, §5) is
/// something a person can look at from the app rather than from a database.
class UsageScreen extends StatefulWidget {
  const UsageScreen({super.key, required this.session, this.client});

  final UserSession session;

  /// The HTTP client, replaceable so a test can answer the two requests the
  /// screen makes and assert what they carried.
  final http.Client? client;

  @override
  State<UsageScreen> createState() => _UsageScreenState();
}

class _UsageScreenState extends State<UsageScreen> {
  late final UsageService _service;
  MonthlyUsage? _usage;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _service =
        UsageService(authToken: widget.session.token, client: widget.client);
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final usage = await _service.fetch();
      if (!mounted) return;
      setState(() => _usage = usage);
    } on UsageUnavailable catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Usage this month'), elevation: 0),
      body: _body(context),
    );
  }

  Widget _body(BuildContext context) {
    if (_loading && _usage == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final usage = _usage;
    if (usage == null) {
      return _Unavailable(
        message: _error ?? 'Could not load your usage.',
        onRetry: _load,
      );
    }
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        Text(
          'What your account has used since the first of the month, as the '
          'server counted it — the same on every device you sign in on. The '
          'counts start again on the first of next month.',
          style: AppText.caption.copyWith(color: context.colors.textMuted),
        ),
        const SizedBox(height: AppSpacing.lg),
        _PlanCard(usage: usage),
        if (usage.quotas.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          _LimitsCard(quotas: usage.quotas),
        ],
        const SizedBox(height: AppSpacing.md),
        _CountedCard(usage: usage),
      ],
    );
  }
}

// ── The three cards ───────────────────────────────────────────────────────

class _PlanCard extends StatelessWidget {
  const _PlanCard({required this.usage});
  final MonthlyUsage usage;

  @override
  Widget build(BuildContext context) {
    return _UsageCard(
      title: 'Plan',
      children: [
        _row(context,
            label: 'Your plan',
            value: tierLabel(usage.tier),
            key: 'usage-tier'),
        _row(context,
            label: 'Counted since',
            value: monthStartLabel(usage.periodStart),
            key: 'usage-since'),
      ],
    );
  }
}

class _LimitsCard extends StatelessWidget {
  const _LimitsCard({required this.quotas});
  final Map<String, QuotaInfo> quotas;

  @override
  Widget build(BuildContext context) {
    final metrics = orderedMetrics(quotas.keys);
    return _UsageCard(
      title: 'Monthly limits',
      subtitle: 'What your plan allows each month, and how much of it is used.',
      children: [
        for (final metric in metrics)
          _QuotaRow(metric: metric, quota: quotas[metric]!),
      ],
    );
  }
}

class _CountedCard extends StatelessWidget {
  const _CountedCard({required this.usage});
  final MonthlyUsage usage;

  @override
  Widget build(BuildContext context) {
    final rows = countedRows(usage);
    return _UsageCard(
      title: 'Also counted',
      subtitle: 'Things without a limit, counted so that a plan can be priced '
          'from what people really use.',
      children: [
        if (rows.isEmpty)
          Text(
            'Nothing counted yet this month.',
            key: const Key('usage-nothing-counted'),
            style: AppText.body.copyWith(color: context.colors.textMuted),
          ),
        for (final row in rows)
          _row(context,
              label: row.label,
              value: row.value,
              key: 'usage-metric-${row.metric}'),
      ],
    );
  }
}

class _QuotaRow extends StatelessWidget {
  const _QuotaRow({required this.metric, required this.quota});
  final String metric;
  final QuotaInfo quota;

  @override
  Widget build(BuildContext context) {
    final label = quotaLabel(metric);
    final value = quota.isUnlimited
        ? '${formatCount(quota.used)} · No limit'
        : '${formatCount(quota.used)} / ${formatCount(quota.limit)}';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _row(context, label: label, value: value, key: 'usage-quota-$metric'),
          if (!quota.isUnlimited && quota.limit > 0)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xs),
              // The fill is darker than its track, not a different hue: a
              // reader who cannot tell red from green still sees how full.
              child: LinearProgressIndicator(
                value: (quota.used / quota.limit).clamp(0.0, 1.0),
                minHeight: 6,
                color: context.colors.textPrimary,
                backgroundColor:
                    context.colors.textMuted.withValues(alpha: 0.25),
              ),
            ),
        ],
      ),
    );
  }
}

class _UsageCard extends StatelessWidget {
  const _UsageCard({
    required this.title,
    required this.children,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: const RoundedRectangleBorder(borderRadius: AppRadii.roundedMd),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: AppText.bodyBold),
            if (subtitle != null) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(subtitle!,
                  style: AppText.caption
                      .copyWith(color: context.colors.textMuted)),
            ],
            const Divider(height: 20),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _Unavailable extends StatelessWidget {
  const _Unavailable({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Could not load your usage.',
                key: const Key('usage-error'), style: AppText.bodyBold),
            const SizedBox(height: AppSpacing.xs),
            Text(message,
                textAlign: TextAlign.center,
                style:
                    AppText.caption.copyWith(color: context.colors.textMuted)),
            const SizedBox(height: AppSpacing.lg),
            FilledButton.icon(
              key: const Key('usage-retry'),
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}

/// A label on the left, its number on the right, never on one line when the
/// two would not fit — a 360 dp phone holds „Homework sent (per student)" and
/// „12 / 5" only if the label may wrap.
Widget _row(BuildContext context,
    {required String label, required String value, required String key}) {
  return Padding(
    key: Key(key),
    padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: Text(label, style: AppText.body)),
        const SizedBox(width: AppSpacing.md),
        Text(value, style: AppText.bodyBold, textAlign: TextAlign.end),
      ],
    ),
  );
}

// ── Words for the wire names ──────────────────────────────────────────────
//
// Top-level so a test can hold them without pumping a screen. The wire names
// are the server's (`services/entitlementService.js`, METRIC and ENT); a
// name this file does not know is still shown, humanised, rather than
// dropped — a counter nobody can see is the fault this screen exists to end.

const _quotaLabels = <String, String>{
  'ai_tutorials': 'AI tutorials',
  'ai_review_words': 'AI review comments',
  'assignments': 'Homework sent (per student)',
  'ai_comments': 'AI comments',
};

/// The metered counters, in the order they are shown, with how each is said.
const _countedOrder = <String>[
  'agora_seconds',
  'mp4_renders',
  'mp4_render_seconds',
  'tts_characters',
  'scanned_pages',
  'ai_tutorial_tokens',
  'ai_review_tokens',
];

const _countedLabels = <String, String>{
  'agora_seconds': 'Voice in sessions',
  'mp4_renders': 'Videos exported',
  'mp4_render_seconds': 'Video rendered',
  'tts_characters': 'Narration spoken by a voice',
  'scanned_pages': 'Book pages scanned',
  'ai_tutorial_tokens': 'AI tutorial writing',
  'ai_review_tokens': 'AI review writing',
};

class CountedRow {
  const CountedRow(
      {required this.metric, required this.label, required this.value});
  final String metric;
  final String label;
  final String value;
}

String quotaLabel(String metric) => _quotaLabels[metric] ?? humanise(metric);

String tierLabel(String tier) {
  switch (tier) {
    case 'premium':
      return 'Premium';
    case 'pro':
      return 'Pro';
    case 'club':
      return 'Club';
    case 'free':
      return 'Free';
    default:
      return humanise(tier);
  }
}

const _months = <String>[
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

/// „1 September 2026" for the month the numbers count from.
String monthStartLabel(DateTime periodStart) {
  final utc = periodStart.toUtc();
  return '1 ${_months[utc.month - 1]} ${utc.year}';
}

/// `ai_review_words` → „Ai review words": a name nobody wrote a label for.
String humanise(String wire) {
  final words = wire.replaceAll('_', ' ').trim();
  if (words.isEmpty) return wire;
  return words[0].toUpperCase() + words.substring(1);
}

/// `1234567` → „1,234,567".
String formatCount(int n) {
  final digits = n.abs().toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
    buffer.write(digits[i]);
  }
  return n < 0 ? '-$buffer' : buffer.toString();
}

/// Known quota metrics first, in the label table's order, then the rest.
List<String> orderedMetrics(Iterable<String> metrics) {
  final known = _quotaLabels.keys.where(metrics.contains).toList();
  final unknown = metrics.where((m) => !_quotaLabels.containsKey(m)).toList()
    ..sort();
  return [...known, ...unknown];
}

/// The rows of „Also counted": every metered counter the plan puts no limit
/// on, said in the reader's units. Voice is minutes (the server's, rounded up
/// as the provider bills), rendered video is minutes, every voice provider's
/// characters are one row, and a quota metric never appears here twice.
List<CountedRow> countedRows(MonthlyUsage usage) {
  final metrics = Map<String, int>.from(usage.metrics)
    ..removeWhere((key, _) => usage.quotas.containsKey(key));

  var narration = 0;
  for (final key in metrics.keys.toList()) {
    final match = RegExp(r'^tts_[a-z]+_characters$').firstMatch(key);
    if (match != null) {
      narration += metrics.remove(key)!;
    }
  }
  if (narration > 0) metrics['tts_characters'] = narration;

  String say(String metric, int value) {
    switch (metric) {
      case 'agora_seconds':
        return '${formatCount(usage.voiceMinutes)} min';
      case 'mp4_render_seconds':
        return '${formatCount((value / 60).ceil())} min';
      case 'tts_characters':
        return '${formatCount(value)} characters';
      case 'ai_tutorial_tokens':
      case 'ai_review_tokens':
        return '${formatCount(value)} tokens';
      default:
        return formatCount(value);
    }
  }

  final rows = <CountedRow>[];
  for (final metric in _countedOrder) {
    final value = metrics.remove(metric);
    if (value == null) continue;
    rows.add(CountedRow(
        metric: metric,
        label: _countedLabels[metric]!,
        value: say(metric, value)));
  }
  for (final metric in metrics.keys.toList()..sort()) {
    rows.add(CountedRow(
        metric: metric,
        label: humanise(metric),
        value: formatCount(metrics[metric]!)));
  }
  return rows;
}

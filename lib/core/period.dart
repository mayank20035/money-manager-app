import 'package:intl/intl.dart';

enum PeriodKind { week, month, year }

/// A calendar week (Monday first), month or year that Insights reports on.
class Period {
  const Period._(this.kind, this.start);

  /// The period of [kind] that contains [date].
  factory Period.containing(PeriodKind kind, DateTime date) {
    final start = switch (kind) {
      PeriodKind.week => DateTime(date.year, date.month, date.day - (date.weekday - DateTime.monday)),
      PeriodKind.month => DateTime(date.year, date.month),
      PeriodKind.year => DateTime(date.year),
    };
    return Period._(kind, start);
  }

  factory Period.current(PeriodKind kind) => Period.containing(kind, DateTime.now());

  final PeriodKind kind;

  /// First instant of the period (local midnight).
  final DateTime start;

  /// First instant after the period.
  DateTime get end => shift(1).start;

  /// The period [n] steps later (negative for earlier).
  Period shift(int n) => Period._(
        kind,
        switch (kind) {
          PeriodKind.week => DateTime(start.year, start.month, start.day + 7 * n),
          PeriodKind.month => DateTime(start.year, start.month + n),
          PeriodKind.year => DateTime(start.year + n),
        },
      );

  bool contains(DateTime t) => !t.isBefore(start) && t.isBefore(end);

  bool get isCurrent => contains(DateTime.now());

  /// The same moment seen as another kind of period: the current one when
  /// this period is current, otherwise the one containing this period's start.
  Period as(PeriodKind other) => Period.containing(other, isCurrent ? DateTime.now() : start);

  /// Chart buckets: days for a week or month, months for a year.
  List<DateTime> get slots => switch (kind) {
        PeriodKind.week => [for (var i = 0; i < 7; i++) DateTime(start.year, start.month, start.day + i)],
        PeriodKind.month => [
            for (var d = 1; d <= DateTime(start.year, start.month + 1, 0).day; d++) DateTime(start.year, start.month, d)
          ],
        PeriodKind.year => [for (var m = 1; m <= 12; m++) DateTime(start.year, m)],
      };

  /// Index into [slots] for a moment inside the period.
  int slotOf(DateTime t) => switch (kind) {
        PeriodKind.week => DateTime(t.year, t.month, t.day).difference(start).inHours ~/ 24,
        PeriodKind.month => t.day - 1,
        PeriodKind.year => t.month - 1,
      };

  /// Days counted for daily averages: up to today for the current period.
  int get daysElapsed {
    final until = isCurrent ? DateTime.now() : end.subtract(const Duration(days: 1));
    final last = DateTime(until.year, until.month, until.day);
    return (last.difference(start).inHours / 24).round() + 1;
  }

  /// "week", "month" or "year" — for sentences like "No spending this week".
  String get noun => kind.name;

  /// "This month" for the current period, else e.g. "Last month" or null.
  String? get relative {
    if (isCurrent) return 'This $noun';
    if (shift(1).isCurrent) return 'Last $noun';
    return null;
  }

  /// "17 – 23 Nov 2026", "November 2026" or "2026".
  String get label {
    switch (kind) {
      case PeriodKind.week:
        final last = end.subtract(const Duration(days: 1));
        if (start.month == last.month) {
          return '${start.day} – ${DateFormat('d MMM yyyy').format(last)}';
        }
        if (start.year == last.year) {
          return '${DateFormat('d MMM').format(start)} – ${DateFormat('d MMM yyyy').format(last)}';
        }
        return '${DateFormat('d MMM yyyy').format(start)} – ${DateFormat('d MMM yyyy').format(last)}';
      case PeriodKind.month:
        return DateFormat('MMMM yyyy').format(start);
      case PeriodKind.year:
        return '${start.year}';
    }
  }

  @override
  bool operator ==(Object other) => other is Period && other.kind == kind && other.start == start;

  @override
  int get hashCode => Object.hash(kind, start);
}

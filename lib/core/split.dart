/// Exact split math on integer minor units.
///
/// Percentages are converted to basis points (1% = 100bp) and every share is
/// floored, so the shares never exceed the amount and any rounding remainder
/// stays with the source bucket — totals always reconcile to the paisa.
library;

const fullBasisPoints = 10000;

int percentToBasisPoints(double percent) => (percent * 100).round();

double basisPointsToPercent(int bp) => bp / 100;

/// Share of [amountMinor] for [bp] basis points (floored).
int shareOf(int amountMinor, int bp) => amountMinor * bp ~/ fullBasisPoints;

/// Splits [amountMinor] by basis points per target. Targets with no share are dropped.
Map<String, int> splitByBasisPoints(int amountMinor, Map<String, int> bpByTarget) {
  final out = <String, int>{};
  bpByTarget.forEach((id, bp) {
    if (bp <= 0) return;
    final share = shareOf(amountMinor, bp);
    if (share > 0) out[id] = share;
  });
  return out;
}

/// Equal split of 100% across [count] targets, in basis points. The leftover
/// basis points (e.g. 10000 / 3) go to the first targets so the sum is exactly 100%.
List<int> equalBasisPoints(int count) {
  if (count <= 0) return const [];
  final base = fullBasisPoints ~/ count;
  final extra = fullBasisPoints - base * count;
  return List.generate(count, (i) => base + (i < extra ? 1 : 0));
}

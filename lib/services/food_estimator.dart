import 'dart:math';

import 'package:puppal_app/services/food_database.dart';

class FoodEstimator {
  // Public entrypoint: estimate grams per cup for a custom brand name
  static Future<int> estimateDensityForBrand(String brandName) async {
    final trimmed = brandName.trim();
    if (trimmed.isEmpty) {
      return _defaultDensity();
    }
    final items = await FoodDatabase.load();

    // Compute similarity to each known brand and take the best match
    double bestScore = -1.0;
    FoodItem? best;
    for (final item in items) {
      final s = _similarity(trimmed.toLowerCase(), item.brand.toLowerCase());
      if (s > bestScore) {
        bestScore = s;
        best = item;
      }
    }

    // If good match, use its density; otherwise use robust median of all
    if (best != null && bestScore >= 0.55) {
      return best.densityGramsPerCup;
    }
    return _medianDensity(items);
  }

  // ---- helpers ----

  static int _defaultDensity() => 112; // general dry kibble ballpark

  static int _medianDensity(List<FoodItem> items) {
    final values = items.map((e) => e.densityGramsPerCup).toList()..sort();
    if (values.isEmpty) return _defaultDensity();
    final mid = values.length ~/ 2;
    if (values.length.isOdd) return values[mid];
    return ((values[mid - 1] + values[mid]) / 2).round();
  }

  // Token-based similarity with Jaccard + partial ratio fallback
  static double _similarity(String a, String b) {
    final ta = _tokens(a);
    final tb = _tokens(b);
    if (ta.isEmpty || tb.isEmpty) return 0.0;
    final inter = ta.intersection(tb).length;
    final union = ta.union(tb).length;
    final jaccard = union == 0 ? 0.0 : inter / union;

    // Partial char overlap to catch near-matches
    final partial = _partialRatio(a, b);

    // Weighted blend
    return 0.7 * jaccard + 0.3 * partial;
  }

  static Set<String> _tokens(String s) {
    return s
        .replaceAll(RegExp(r"[^a-z0-9\s]"), " ")
        .split(RegExp(r"\s+"))
        .where((t) => t.isNotEmpty)
        .toSet();
  }

  // Crude partial ratio: longest common substring length normalized
  static double _partialRatio(String a, String b) {
    final lcs = _longestCommonSubstring(a, b);
    final denom = max(a.length, b.length);
    if (denom == 0) return 0.0;
    return lcs / denom;
  }

  static int _longestCommonSubstring(String a, String b) {
    final m = a.length;
    final n = b.length;
    if (m == 0 || n == 0) return 0;
    final dp = List.generate(m + 1, (_) => List<int>.filled(n + 1, 0));
    int best = 0;
    for (int i = 1; i <= m; i++) {
      for (int j = 1; j <= n; j++) {
        if (a[i - 1] == b[j - 1]) {
          dp[i][j] = dp[i - 1][j - 1] + 1;
          if (dp[i][j] > best) best = dp[i][j];
        } else {
          dp[i][j] = 0;
        }
      }
    }
    return best;
  }
}

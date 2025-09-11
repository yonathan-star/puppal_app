import 'dart:convert';
import 'package:http/http.dart' as http;

class BreedMatch {
  final String name;
  final String group;
  final double similarity;
  BreedMatch({
    required this.name,
    required this.group,
    required this.similarity,
  });
}

class BreedLookupService {
  // Optional API keys. Set these at runtime if you have keys.
  // Example: BreedLookupService.dogApiKey = '<YOUR_KEY>'
  static String? dogApiKey;
  static String? catApiKey;

  static Future<BreedMatch?> lookupDogBreed(String query) async {
    try {
      final url = Uri.parse(
        'https://api.thedogapi.com/v1/breeds/search?q=${Uri.encodeComponent(query)}',
      );
      final resp = await http.get(
        url,
        headers: {
          if (dogApiKey != null && dogApiKey!.isNotEmpty)
            'x-api-key': dogApiKey!,
        },
      );
      if (resp.statusCode != 200) return null;
      final list = (jsonDecode(resp.body) as List).cast<Map<String, dynamic>>();
      if (list.isEmpty) return null;
      final best = _bestMatch(
        query,
        list.map((b) => b['name'] as String? ?? '').toList(),
      );
      if (best == null) return null;
      final chosen = list.firstWhere(
        (b) =>
            (b['name'] as String? ?? '').toLowerCase() ==
            best.name.toLowerCase(),
        orElse: () => list.first,
      );
      return BreedMatch(
        name: chosen['name'] ?? best.name,
        group: chosen['breed_group'] ?? 'Unknown',
        similarity: best.score,
      );
    } catch (_) {
      return null;
    }
  }

  static Future<BreedMatch?> lookupCatBreed(String query) async {
    try {
      final url = Uri.parse(
        'https://api.thecatapi.com/v1/breeds/search?q=${Uri.encodeComponent(query)}',
      );
      final resp = await http.get(
        url,
        headers: {
          if (catApiKey != null && catApiKey!.isNotEmpty)
            'x-api-key': catApiKey!,
        },
      );
      if (resp.statusCode != 200) return null;
      final list = (jsonDecode(resp.body) as List).cast<Map<String, dynamic>>();
      if (list.isEmpty) return null;
      final best = _bestMatch(
        query,
        list.map((b) => b['name'] as String? ?? '').toList(),
      );
      if (best == null) return null;
      final chosen = list.firstWhere(
        (b) =>
            (b['name'] as String? ?? '').toLowerCase() ==
            best.name.toLowerCase(),
        orElse: () => list.first,
      );
      return BreedMatch(
        name: chosen['name'] ?? best.name,
        group: chosen['origin'] ?? 'Unknown',
        similarity: best.score,
      );
    } catch (_) {
      return null;
    }
  }

  // Return best matching name among candidates
  static _Best? _bestMatch(String query, List<String> candidates) {
    double best = -1.0;
    String? bestName;
    for (final c in candidates) {
      final s = _similarity(query, c);
      if (s > best) {
        best = s;
        bestName = c;
      }
    }
    if (bestName == null) return null;
    return _Best(bestName, best);
  }

  // Similarity: token Jaccard + partial ratio blend
  static double _similarity(String a, String b) {
    a = a.toLowerCase();
    b = b.toLowerCase();
    final ta = _tokens(a);
    final tb = _tokens(b);
    final inter = ta.intersection(tb).length.toDouble();
    final union = ta.union(tb).length.toDouble().clamp(1, double.infinity);
    final jaccard = inter / union;
    final partial = _partialRatio(a, b);
    return 0.7 * jaccard + 0.3 * partial;
  }

  static Set<String> _tokens(String s) => s
      .replaceAll(RegExp(r"[^a-z0-9\s]"), " ")
      .split(RegExp(r"\s+"))
      .where((t) => t.isNotEmpty)
      .toSet();

  static double _partialRatio(String a, String b) {
    final lcs = _longestCommonSubstring(a, b).toDouble();
    final denom = a.length > b.length ? a.length : b.length;
    return denom == 0 ? 0.0 : lcs / denom;
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

class _Best {
  final String name;
  final double score;
  _Best(this.name, this.score);
}

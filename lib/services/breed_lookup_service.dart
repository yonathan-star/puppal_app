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
  static Future<BreedMatch?> lookupDogBreed(String query) async {
    final url = Uri.parse(
      'https://api.thedogapi.com/v1/breeds/search?q=${Uri.encodeComponent(query)}',
    );
    final resp = await http.get(url);
    if (resp.statusCode != 200) return null;
    final list = jsonDecode(resp.body) as List;
    if (list.isEmpty) return null;
    final breed = list.first;
    return BreedMatch(
      name: breed['name'] ?? '',
      group: breed['breed_group'] ?? 'Unknown',
      similarity: _similarity(query, breed['name'] ?? ''),
    );
  }

  static Future<BreedMatch?> lookupCatBreed(String query) async {
    final url = Uri.parse(
      'https://api.thecatapi.com/v1/breeds/search?q=${Uri.encodeComponent(query)}',
    );
    final resp = await http.get(url);
    if (resp.statusCode != 200) return null;
    final list = jsonDecode(resp.body) as List;
    if (list.isEmpty) return null;
    final breed = list.first;
    return BreedMatch(
      name: breed['name'] ?? '',
      group: breed['origin'] ?? 'Unknown',
      similarity: _similarity(query, breed['name'] ?? ''),
    );
  }

  // Simple similarity: normalized longest common substring
  static double _similarity(String a, String b) {
    a = a.toLowerCase();
    b = b.toLowerCase();
    int lcs = _longestCommonSubstring(a, b);
    return lcs / (a.length > b.length ? a.length : b.length);
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

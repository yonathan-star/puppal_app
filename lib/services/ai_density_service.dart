import 'dart:convert';

import 'package:http/http.dart' as http;

class AiDensityService {
  AiDensityService({required this.baseUrl});
  final String baseUrl; // e.g., https://your-worker.example.workers.dev

  Future<int?> estimateDensity(String brand) async {
    final uri = Uri.parse('$baseUrl/ai/estimate_density');
    final resp = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'brand': brand}),
    );
    if (resp.statusCode != 200) return null;
    final json = jsonDecode(resp.body) as Map<String, dynamic>;
    final val = json['grams_per_cup'];
    if (val is num) return val.toInt();
    return int.tryParse('$val');
  }
}

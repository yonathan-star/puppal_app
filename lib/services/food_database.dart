import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

class FoodItem {
  FoodItem({required this.brand, required this.densityGramsPerCup});
  final String brand;
  final int densityGramsPerCup;
}

class FoodDatabase {
  static List<FoodItem>? _cache;

  static Future<List<FoodItem>> load() async {
    if (_cache != null) return _cache!;
    final jsonStr = await rootBundle.loadString('assets/foods.json');
    final list = (jsonDecode(jsonStr) as List)
        .map(
          (e) => FoodItem(
            brand: e['brand'] as String,
            densityGramsPerCup: (e['density_g_per_cup'] as num).toInt(),
          ),
        )
        .toList();
    _cache = list;
    return list;
  }

  static Future<List<FoodItem>> search(String query) async {
    final items = await load();
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return items;
    return items
        .where((f) => f.brand.toLowerCase().contains(q))
        .toList(growable: false);
  }
}

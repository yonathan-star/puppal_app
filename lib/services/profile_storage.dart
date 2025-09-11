import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:puppal_app/model/pet_profile.dart';

class ProfileStorage {
  static const String _key = 'pet_profiles_v1';

  static Future<List<PetProfile>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_key) ?? [];
    return list
        .map((s) => jsonDecode(s) as Map<String, dynamic>)
        .map(PetProfile.fromJson)
        .toList(growable: true);
  }

  static Future<void> save(List<PetProfile> profiles) async {
    final prefs = await SharedPreferences.getInstance();
    final list = profiles.map((p) => jsonEncode(p.toJson())).toList();
    await prefs.setStringList(_key, list);
  }

  static Future<void> upsert(PetProfile profile) async {
    final profiles = await load();
    final idx = profiles.indexWhere((p) => p.uidHex == profile.uidHex);
    if (idx >= 0) {
      profiles[idx] = profile;
    } else {
      profiles.add(profile);
    }
    await save(profiles);
  }

  static Future<void> removeByUid(String uidHex) async {
    final profiles = await load();
    profiles.removeWhere((p) => p.uidHex.toUpperCase() == uidHex.toUpperCase());
    await save(profiles);
  }
}

class TimeWindow {
  TimeWindow({required this.startMinutes, required this.endMinutes});
  final int startMinutes; // minutes from midnight [0..1439]
  final int endMinutes; // minutes from midnight [0..1439]

  Map<String, dynamic> toJson() => {
    'startMinutes': startMinutes,
    'endMinutes': endMinutes,
  };

  static TimeWindow fromJson(Map<String, dynamic> json) => TimeWindow(
    startMinutes: (json['startMinutes'] as num).toInt(),
    endMinutes: (json['endMinutes'] as num).toInt(),
  );
}

class PetProfile {
  PetProfile({
    required this.uidHex,
    required this.type,
    this.name,
    this.foodType,
    this.gramsPerDay,
    this.foodBrand,
    this.foodDensityGramsPerCup,
    this.allowedWindows,
    this.weightLb,
    this.breed,
    this.ageStage,
    this.neutered,
    this.activity,
    this.bcs,
  });

  final String uidHex; // 8-hex uppercase string
  final String type; // 'dog' | 'cat'
  final String? name; // optional user-friendly name
  final String? foodType; // legacy field
  final int? gramsPerDay; // daily food amount

  final String? foodBrand; // selected brand name
  final int? foodDensityGramsPerCup; // density used for dosing

  final List<TimeWindow>? allowedWindows; // daily allowed entry windows

  // Additional profile details
  final double? weightLb; // stored in pounds
  final String? breed; // selected/confirmed breed label
  final String? ageStage; // 'puppyKitten' | 'adult' | 'senior'
  final bool? neutered; // spay/neuter status
  final int? activity; // 1..5
  final int? bcs; // 1..9

  Map<String, dynamic> toJson() => {
    'uidHex': uidHex,
    'type': type,
    'name': name,
    'foodType': foodType,
    'gramsPerDay': gramsPerDay,
    'foodBrand': foodBrand,
    'foodDensityGramsPerCup': foodDensityGramsPerCup,
    'allowedWindows': allowedWindows?.map((w) => w.toJson()).toList(),
    'weightLb': weightLb,
    'breed': breed,
    'ageStage': ageStage,
    'neutered': neutered,
    'activity': activity,
    'bcs': bcs,
  };

  static PetProfile fromJson(Map<String, dynamic> json) => PetProfile(
    uidHex: (json['uidHex'] as String).toUpperCase(),
    type: json['type'] as String,
    name: json['name'] as String?,
    foodType: json['foodType'] as String?,
    gramsPerDay: json['gramsPerDay'] is int
        ? json['gramsPerDay'] as int
        : (json['gramsPerDay'] == null
              ? null
              : int.tryParse('${json['gramsPerDay']}')),
    foodBrand: json['foodBrand'] as String?,
    foodDensityGramsPerCup: json['foodDensityGramsPerCup'] is int
        ? json['foodDensityGramsPerCup'] as int
        : (json['foodDensityGramsPerCup'] == null
              ? null
              : int.tryParse('${json['foodDensityGramsPerCup']}')),
    allowedWindows: (json['allowedWindows'] as List?)
        ?.map((e) => TimeWindow.fromJson(e as Map<String, dynamic>))
        .toList(),
    weightLb: (json['weightLb'] as num?)?.toDouble(),
    breed: json['breed'] as String?,
    ageStage: json['ageStage'] as String?,
    neutered: json['neutered'] as bool?,
    activity: (json['activity'] as num?)?.toInt(),
    bcs: (json['bcs'] as num?)?.toInt(),
  );
}

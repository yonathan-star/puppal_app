// Local, offline "AI" for feeding estimates using standard vet equations.
// RER = 70 * (kg^0.75)
// MER = RER * factor (species, age, neuter, activity, breed bias, body condition)
// Grams/day = MER_kcal / kcalPerGram
//
// DISCLAIMER: General guidance only. Consult your veterinarian.

import 'dart:math';

enum Species { dog, cat }

enum AgeStage { puppyKitten, adult, senior }

class FoodProfile {
  final double? kcalPerGram;
  final double? kcalPerCup;
  final double? gramsPerCup;
  const FoodProfile({this.kcalPerGram, this.kcalPerCup, this.gramsPerCup});
  double get kcalPerGramResolved {
    if (kcalPerGram != null && kcalPerGram! > 0) return kcalPerGram!;
    if ((kcalPerCup ?? 0) > 0 && (gramsPerCup ?? 0) > 0) {
      return kcalPerCup! / gramsPerCup!;
    }
    return 3.6; // common dry kibble default
  }
}

class FeedingInput {
  final Species species;
  final double weightKg;
  final String breedKey;
  final AgeStage ageStage;
  final bool neutered;
  final int activityLevel; // 1..5 (3 = normal)
  final int bcs; // Body Condition Score 1..9 (5 = ideal)
  final FoodProfile food;
  FeedingInput({
    required this.species,
    required this.weightKg,
    required this.breedKey,
    required this.ageStage,
    required this.neutered,
    required this.activityLevel,
    required this.bcs,
    required this.food,
  });
}

class FeedingResult {
  final double rerKcal, merKcal, gramsPerDay;
  final double? cupsPerDay;
  final List<String> explanation;
  FeedingResult({
    required this.rerKcal,
    required this.merKcal,
    required this.gramsPerDay,
    required this.cupsPerDay,
    required this.explanation,
  });
}

class _BreedMeta {
  final String group;
  final double bias;
  const _BreedMeta(this.group, this.bias);
}

// Minimal built-in tables (expand as you wish).
const Map<String, _BreedMeta> _DOG_BREEDS = {
  "Mixed/Unknown": _BreedMeta("medium", 0.0),
  "Chihuahua": _BreedMeta("toy", -0.05),
  "French Bulldog": _BreedMeta("brachy", -0.10),
  "Beagle": _BreedMeta("small", 0.0),
  "Australian Shepherd": _BreedMeta("working", 0.10),
  "Border Collie": _BreedMeta("working", 0.12),
  "German Shepherd": _BreedMeta("large", 0.05),
  "Golden Retriever": _BreedMeta("large", 0.05),
  "Labrador Retriever": _BreedMeta("large", 0.05),
  "Great Dane": _BreedMeta("giant", -0.05),
  "Greyhound": _BreedMeta("sighthound", 0.05),
  "Siberian Husky": _BreedMeta("working", 0.10),
};

const Map<String, _BreedMeta> _CAT_BREEDS = {
  "Domestic Shorthair": _BreedMeta("indoor", -0.05),
  "Domestic Longhair": _BreedMeta("indoor", -0.05),
  "Siamese": _BreedMeta("medium", 0.05),
  "Maine Coon": _BreedMeta("large", 0.05),
  "Bengal": _BreedMeta("medium", 0.05),
  "Ragdoll": _BreedMeta("large", 0.03),
  "Sphynx": _BreedMeta("medium", 0.05),
  "Mixed/Unknown": _BreedMeta("medium", 0.0),
};

class LocalFeedingAI {
  static final dogBreeds = (_DOG_BREEDS.keys.toList()..sort());
  static final catBreeds = (_CAT_BREEDS.keys.toList()..sort());

  static FeedingResult estimate(FeedingInput i) {
    final steps = <String>[];
    final rer = 70.0 * pow(i.weightKg, 0.75);
    steps.add("RER = 70 × (kg^0.75) = ${rer.toStringAsFixed(0)} kcal/day");

    double factor = _baseFactor(i); // species + age + neuter
    steps.add("Base MER factor: ${factor.toStringAsFixed(2)}");

    final meta = i.species == Species.dog
        ? (_DOG_BREEDS[i.breedKey] ?? _DOG_BREEDS["Mixed/Unknown"]!)
        : (_CAT_BREEDS[i.breedKey] ?? _CAT_BREEDS["Mixed/Unknown"]!);
    factor += meta.bias; // breed bias
    steps.add(
      "Breed '${meta.group}' bias ${_s(meta.bias)} → ${factor.toStringAsFixed(2)}",
    );

    final actAdj = (i.activityLevel - 3) * 0.10; // activity
    factor += actAdj;
    steps.add(
      "Activity ${i.activityLevel} ${_s(actAdj)} → ${factor.toStringAsFixed(2)}",
    );

    final bcsAdj = (5 - i.bcs) * 0.05; // body condition
    factor += bcsAdj;
    steps.add("BCS ${i.bcs} ${_s(bcsAdj)} → ${factor.toStringAsFixed(2)}");

    factor = factor.clamp(0.8, 3.5);
    steps.add("Clamped MER factor: ${factor.toStringAsFixed(2)}");

    final mer = rer * factor;
    steps.add("MER = ${mer.toStringAsFixed(0)} kcal/day");

    final kcalPerGram = i.food.kcalPerGramResolved;
    final gramsPerDay = mer / kcalPerGram;
    steps.add(
      "Energy ${kcalPerGram.toStringAsFixed(2)} kcal/g → ${gramsPerDay.toStringAsFixed(0)} g/day",
    );

    double? cupsPerDay;
    if ((i.food.kcalPerCup ?? 0) > 0 && (i.food.gramsPerCup ?? 0) > 0) {
      cupsPerDay = gramsPerDay / i.food.gramsPerCup!;
      steps.add(
        "≈ ${cupsPerDay.toStringAsFixed(2)} cups/day (at ${i.food.gramsPerCup} g/cup)",
      );
    }

    return FeedingResult(
      rerKcal: rer.toDouble(),
      merKcal: mer.toDouble(),
      gramsPerDay: gramsPerDay,
      cupsPerDay: cupsPerDay,
      explanation: steps,
    );
  }

  static double _baseFactor(FeedingInput i) {
    if (i.species == Species.dog) {
      switch (i.ageStage) {
        case AgeStage.puppyKitten:
          return i.neutered ? 2.0 : 2.2;
        case AgeStage.adult:
          return i.neutered ? 1.6 : 1.8;
        case AgeStage.senior:
          return i.neutered ? 1.4 : 1.6;
      }
    } else {
      switch (i.ageStage) {
        case AgeStage.puppyKitten:
          return i.neutered ? 2.0 : 2.2;
        case AgeStage.adult:
          return i.neutered ? 1.2 : 1.4;
        case AgeStage.senior:
          return i.neutered ? 1.1 : 1.3;
      }
    }
  }

  static String _s(double v) =>
      v >= 0 ? "+${v.toStringAsFixed(2)}" : v.toStringAsFixed(2);
}

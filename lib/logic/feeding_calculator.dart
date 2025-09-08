class FeedingCalculator {
  /// Simulates a "local ai" – replace with actual ML inference for production.
  static int calculateGramsPerDay({
    required String breed,
    required double weightKg,
    bool isDog = true,
  }) {
    // Recognize certain breeds, fallback to average for unknown
    double gramsPerKg;
    final breedLower = breed.toLowerCase();
    if (!isDog) {
      gramsPerKg = 45;
    } else if (breedLower.contains('chihuahua')) {
      gramsPerKg = 16.0;
    } else if (breedLower.contains('labrador')) {
      gramsPerKg = 14.0;
    } else if (breedLower.contains('poodle')) {
      gramsPerKg = 13.0;
    } else if (breedLower.contains('mastiff') || breedLower.contains('great dane')) {
      gramsPerKg = 11.0; // Large breeds
    } else {
      gramsPerKg = 14.0; // Default for unknown/AI-estimated
    }
    return (weightKg * gramsPerKg).round();
  }
}
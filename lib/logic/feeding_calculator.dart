class FeedingCalculator {
  /// Simple fallback estimator. Input weight must be in pounds (lb).
  /// Internally converts to kg and applies species-aware defaults with light breed bias.
  static int calculateGramsPerDay({
    required String breed,
    required double weightLb,
    bool isDog = true,
  }) {
    final double weightKg = weightLb * 0.45359237;

    // Species defaults (grams per kg of body weight)
    double gramsPerKg = isDog ? 14.0 : 45.0;

    final breedLower = breed.toLowerCase();
    if (isDog) {
      if (breedLower.contains('chihuahua'))
        gramsPerKg = 16.0;
      else if (breedLower.contains('labrador'))
        gramsPerKg = 14.0;
      else if (breedLower.contains('poodle'))
        gramsPerKg = 13.0;
      else if (breedLower.contains('mastiff') ||
          breedLower.contains('great dane'))
        gramsPerKg = 11.0;
    } else {
      // Cat light adjustments
      if (breedLower.contains('siamese'))
        gramsPerKg = 42.0;
      else if (breedLower.contains('maine coon'))
        gramsPerKg = 48.0;
    }

    final grams = (weightKg * gramsPerKg).round();
    return grams.clamp(0, 5000); // basic sanity cap
  }
}

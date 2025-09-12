import 'package:flutter/material.dart';
import 'package:puppal_app1/screens/home.dart';
import 'package:puppal_app1/screens/theme.dart';
import 'package:puppal_app1/services/breed_lookup_service.dart';

void main() {
  // Optionally supply API keys via --dart-define
  BreedLookupService.dogApiKey = const String.fromEnvironment('DOG_API_KEY');
  BreedLookupService.catApiKey = const String.fromEnvironment('CAT_API_KEY');
  runApp(MaterialApp(theme: primaryTheme, home: Home()));
}

import 'package:flutter/material.dart';

class AppColors {
  // Primary brand color (softer teal-blue, pet-friendly feel)
  static Color primaryColor = const Color.fromRGBO(52, 152, 219, 1); // soft blue
  static Color primaryAccent = const Color.fromRGBO(41, 128, 185, 1); // deeper blue accent

  // Background / surfaces (blue-grey theme)
  static Color secondaryColor = const Color.fromRGBO(44, 62, 80, 1);   // dark blue-grey
  static Color secondaryAccent = const Color.fromRGBO(52, 73, 94, 1); // medium blue-grey
  static Color secondaryBright = const Color.fromRGBO(70, 110, 140, 1); // brighter blue-grey between secondaryColor and secondaryAccent

  // Texts
  static Color titleColor = const Color.fromRGBO(236, 240, 241, 1); // light grey-white
  static Color textColor = const Color.fromRGBO(189, 195, 199, 1);  // softer grey

  // Semantic
  static Color successColor = const Color.fromRGBO(39, 174, 96, 1);   // fresh green
  static Color highlightColor = const Color.fromRGBO(241, 196, 15, 1); // golden yellow
}


ThemeData primaryTheme = ThemeData(
  colorScheme: ColorScheme.fromSeed(seedColor: 
    AppColors.primaryColor),


    scaffoldBackgroundColor: AppColors.secondaryAccent,
    

  appBarTheme: AppBarTheme(
    backgroundColor: AppColors.secondaryColor,
    foregroundColor: AppColors.textColor,
    surfaceTintColor: Colors.transparent,
    centerTitle: true,
  ),



   textTheme: TextTheme(
    bodyMedium: TextStyle(
      color: AppColors.textColor,
      fontSize: 16,
      letterSpacing: 1,
    ),
    headlineMedium: TextStyle(
      color: AppColors.titleColor, 
      fontSize: 16,
      fontWeight: FontWeight.bold, 
      letterSpacing: 1,
    ),
    titleMedium: TextStyle(
      color: AppColors.titleColor, 
      fontSize: 50, 
      fontWeight: FontWeight.bold,
      letterSpacing: 2,
    ),
  ),



  cardTheme: CardThemeData(
    color: AppColors.primaryAccent.withOpacity(0.8),
    surfaceTintColor: Colors.transparent,
    shape: RoundedRectangleBorder(
    ),
    shadowColor: Colors.transparent,
    margin: const EdgeInsets.symmetric(vertical: 20,horizontal: 0),
  ),
  
  );

import 'package:flutter/material.dart';
import 'package:my_new_app/screens/home.dart';
import 'package:my_new_app/screens/theme.dart';
void main() {
  runApp(
     MaterialApp(
      theme: primaryTheme,
      home: Home(),
    )
  );
}
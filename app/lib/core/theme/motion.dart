import 'package:flutter/material.dart';

/// Navigation helper: a standard route using the app's PageTransitionsTheme
/// (predictive back on Android, a short fade-forward elsewhere). Every push in
/// the app goes through this so transitions are identical everywhere.
Route<T> appRoute<T>(Widget page) =>
    MaterialPageRoute<T>(builder: (_) => page);

import 'package:flutter/services.dart';

/// Shared numeric-input helpers for the calculator tools.
///
/// The domain math (grading.dart / tuition.dart) is correct but trusts its
/// inputs; these keep out-of-range or malformed values from ever reaching it.
/// Fields use [decimalInput] to block non-numeric characters, and callers clamp
/// the parsed value with [clampCgpa] / [clampNonNeg] / [clampPercent] before
/// passing it to a projection.

/// Allows only digits and a single decimal point (no signs, no letters). Use in
/// a field's `inputFormatters`.
final List<TextInputFormatter> decimalInput = [
  FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
  // Collapse a second dot: keep the text up to and including the first dot.
  TextInputFormatter.withFunction((oldValue, newValue) {
    final t = newValue.text;
    if (t.indexOf('.') != t.lastIndexOf('.')) return oldValue;
    return newValue;
  }),
];

/// Parse + clamp a CGPA/GPA to the valid [0, 4] range. Returns null if blank or
/// unparseable so the UI can show "—" rather than a bogus number.
double? clampCgpa(String raw) {
  final v = double.tryParse(raw.trim());
  if (v == null) return null;
  return v.clamp(0.0, 4.0);
}

/// Parse + clamp a credit/other non-negative quantity to [0, ∞). Null if blank.
double? clampNonNeg(String raw) {
  final v = double.tryParse(raw.trim());
  if (v == null) return null;
  return v < 0 ? 0.0 : v;
}

/// Parse + clamp a percentage to [0, 100]. Null if blank.
double? clampPercent(String raw) {
  final v = double.tryParse(raw.trim());
  if (v == null) return null;
  return v.clamp(0.0, 100.0);
}

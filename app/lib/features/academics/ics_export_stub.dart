/// Fallback when neither dart:html nor dart:io is available. Never actually used
/// in practice (every Flutter target has one), but keeps the conditional import
/// total and the analyzer happy.
Future<bool> saveOrOpenIcs(String ics, String filename) async => false;

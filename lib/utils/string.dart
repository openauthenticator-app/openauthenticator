import 'package:convertlib/convertlib.dart';

/// Returns whether a given [string] is a valid base 32 string.
bool isValidBase32(String string) {
  try {
    fromBase32(string);
    return true;
  } catch (_) {}
  return false;
}

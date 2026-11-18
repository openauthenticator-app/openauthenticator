import 'dart:convert';

/// Represents a JSON map.
typedef JsonMap = Map<String, dynamic>;

/// Decodes a JSON map from a string.
JsonMap decodeJsonMap(String json) => jsonDecode(json) as JsonMap;

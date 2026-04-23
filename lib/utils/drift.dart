import 'dart:convert';

import 'package:drift/drift.dart';

/// Allows to store [Uint8List] into Drift databases.
class Uint8ListConverter extends TypeConverter<Uint8List, String> {
  /// Creates a new Uint8List converter instance.
  const Uint8ListConverter();

  @override
  Uint8List fromSql(String fromDb) => base64.decode(fromDb);

  @override
  String toSql(Uint8List value) => base64.encode(value);
}

/// Allows to store [Duration] into Drift databases.
class DurationConverter extends TypeConverter<Duration, int> {
  /// Creates a new Uint8List converter instance.
  const DurationConverter();

  @override
  Duration fromSql(int fromDb) => Duration(seconds: fromDb);

  @override
  int toSql(Duration value) => value.inSeconds;
}

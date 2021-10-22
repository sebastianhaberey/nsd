import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';

void nop([a, b]) {}

String? enumValueToString(Object? enumValue) {
  return enumValue != null ? describeEnum(enumValue) : null;
}

T? enumValueFromString<T>(Iterable<T> values, String value) {
  return values
      .firstWhereOrNull((type) => type.toString().split('.').last == value);
}

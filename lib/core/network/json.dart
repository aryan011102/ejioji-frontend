/// Reading JSON without trusting it.
///
/// Every value that crosses the network is `Object?` until something checks
/// it. These helpers do the checking in one place and throw a single, named
/// error when a field is missing or the wrong type, so a backend change shows
/// up as one legible exception rather than a `TypeError` from deep inside a
/// widget build.
class MalformedResponse implements Exception {
  const MalformedResponse(this.field, this.detail);

  final String field;
  final String detail;

  @override
  String toString() => 'MalformedResponse($field: $detail)';
}

typedef Json = Map<String, Object?>;

/// Casts a decoded body to an object, or fails with the field name.
Json asJson(Object? value, [String field = 'body']) {
  if (value is Json) return value;
  if (value is Map) return value.map((k, v) => MapEntry(k.toString(), v));
  throw MalformedResponse(field, 'expected an object, got ${value.runtimeType}');
}

List<Json> asJsonList(Object? value, [String field = 'body']) {
  if (value is! List) {
    throw MalformedResponse(field, 'expected a list, got ${value.runtimeType}');
  }
  return value.map((e) => asJson(e, field)).toList(growable: false);
}

extension JsonReader on Json {
  String str(String key) {
    final v = this[key];
    if (v is String) return v;
    throw MalformedResponse(key, 'expected a string, got ${v.runtimeType}');
  }

  String? strOrNull(String key) {
    final v = this[key];
    return v is String ? v : null;
  }

  int integer(String key) {
    final v = this[key];
    if (v is int) return v;
    if (v is num) return v.toInt();
    throw MalformedResponse(key, 'expected a number, got ${v.runtimeType}');
  }

  int intOr(String key, int fallback) {
    final v = this[key];
    if (v is int) return v;
    if (v is num) return v.toInt();
    return fallback;
  }

  int? intOrNull(String key) {
    final v = this[key];
    if (v is int) return v;
    if (v is num) return v.toInt();
    return null;
  }

  double decimal(String key) {
    final v = this[key];
    if (v is num) return v.toDouble();
    throw MalformedResponse(key, 'expected a number, got ${v.runtimeType}');
  }

  bool flag(String key, {bool fallback = false}) {
    final v = this[key];
    return v is bool ? v : fallback;
  }

  /// The API sends timestamps as ISO 8601 in UTC. They are parsed to local
  /// time here, once, so no screen ever formats a UTC instant as if it were
  /// the user's clock.
  DateTime time(String key) {
    final raw = str(key);
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) {
      throw MalformedResponse(key, 'not a timestamp: $raw');
    }
    return parsed.toLocal();
  }

  DateTime? timeOrNull(String key) {
    final raw = strOrNull(key);
    if (raw == null) return null;
    return DateTime.tryParse(raw)?.toLocal();
  }

  /// A plain calendar date (birth date), which has no timezone and must not
  /// be shifted into one.
  DateTime date(String key) {
    final raw = str(key);
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) {
      throw MalformedResponse(key, 'not a date: $raw');
    }
    return DateTime(parsed.year, parsed.month, parsed.day);
  }

  Json object(String key) => asJson(this[key], key);

  Json? objectOrNull(String key) {
    final v = this[key];
    if (v == null) return null;
    return asJson(v, key);
  }

  List<Json> objects(String key) {
    final v = this[key];
    if (v == null) return const [];
    return asJsonList(v, key);
  }

  List<String> strings(String key) {
    final v = this[key];
    if (v is! List) return const [];
    return v.whereType<String>().toList(growable: false);
  }
}

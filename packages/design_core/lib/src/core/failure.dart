abstract interface class Failure implements Exception {
  String get code;

  String get message;

  Map<String, Object?> get args;
}

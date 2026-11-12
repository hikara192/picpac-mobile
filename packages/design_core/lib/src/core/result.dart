import 'failure.dart';

sealed class Result<T> {
  const Result();

  bool get isOk => this is Ok<T>;

  bool get isErr => this is Err<T>;

  T? get valueOrNull => switch (this) {
    Ok<T>(:final value) => value,
    Err<T>() => null,
  };

  Failure? get failureOrNull => switch (this) {
    Ok<T>() => null,
    Err<T>(:final error) => error,
  };

  T get requireValue => switch (this) {
    Ok<T>(:final value) => value,
    Err<T>(:final error) => throw StateError('expected Ok, got $error'),
  };

  R fold<R>({
    required R Function(T value) ok,
    required R Function(Failure error) err,
  }) => switch (this) {
    Ok<T>(:final value) => ok(value),
    Err<T>(:final error) => err(error),
  };

  Result<R> map<R>(R Function(T value) transform) => switch (this) {
    Ok<T>(:final value) => Ok<R>(transform(value)),
    Err<T>(:final error) => Err<R>(error),
  };

  Result<T> mapError(Failure Function(Failure error) transform) =>
      switch (this) {
        Ok<T>() => this,
        Err<T>(:final error) => Err<T>(transform(error)),
      };
}

final class Ok<T> extends Result<T> {
  const Ok(this.value);

  final T value;

  @override
  bool operator ==(Object other) => other is Ok<T> && other.value == value;

  @override
  int get hashCode => Object.hash(Ok<T>, value);

  @override
  String toString() => 'Ok($value)';
}

final class Err<T> extends Result<T> {
  const Err(this.error);

  final Failure error;

  @override
  bool operator ==(Object other) =>
      other is Err<T> &&
      other.error.runtimeType == error.runtimeType &&
      other.error.code == error.code;

  @override
  int get hashCode => Object.hash(Err<T>, error.runtimeType, error.code);

  @override
  String toString() => 'Err($error)';
}

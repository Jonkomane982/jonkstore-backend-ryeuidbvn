import '../errors/failures.dart';

/// A generic class that holds a value of type [T] or a [Failure].
/// Designed for production-grade error handling.
class Result<T> {
  final T? _value;
  final Failure? _failure;

  Result._(this._value, this._failure);

  /// Creates a success result containing [value].
  factory Result.success(T value) => Result._(value, null);

  /// Creates a failure result containing [failure].
  factory Result.failure(Failure failure) => Result._(null, failure);

  bool get isSuccess => _failure == null;
  bool get isFailure => _failure != null;

  /// Safely retrieves the success value. 
  /// Note: Only call this if [isSuccess] is true.
  T get value => _value as T;

  /// Retrieves the failure.
  Failure get failure => _failure!;

  /// Executes [onSuccess] if success, or [onFailure] if failure,
  /// and returns the result of type [R].
  R fold<R>(R Function(T value) onSuccess, R Function(Failure failure) onFailure) {
    if (isSuccess) {
      return onSuccess(_value as T);
    } else {
      return onFailure(_failure!);
    }
  }

  /// Transforms the success value using [fn].
  Result<R> map<R>(R Function(T) fn) {
    if (isSuccess) {
      return Result.success(fn(_value as T));
    } else {
      return Result.failure(_failure!);
    }
  }
}

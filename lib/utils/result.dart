class Result<T> {
  final T? data;
  final Object? error;
  final StackTrace? stackTrace;
  bool get isOk => error == null;
  const Result.ok(this.data)
      : error = null,
        stackTrace = null;
  const Result.err(this.error, [this.stackTrace]) : data = null;
}
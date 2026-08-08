/// Status for catalogue data views, mirroring the profile module style.
enum CatalogViewStatus { initial, loading, success, failure }

/// Generic immutable state container for a single catalogue resource.
class CatalogState<T> {
  const CatalogState({
    this.status = CatalogViewStatus.initial,
    this.data,
    this.message,
  });

  final CatalogViewStatus status;
  final T? data;
  final String? message;

  bool get isLoading => status == CatalogViewStatus.loading;
  bool get isSuccess => status == CatalogViewStatus.success;
  bool get isFailure => status == CatalogViewStatus.failure;

  CatalogState<T> copyWith({
    CatalogViewStatus? status,
    T? data,
    String? message,
    bool clearMessage = false,
  }) {
    return CatalogState<T>(
      status: status ?? this.status,
      data: data ?? this.data,
      message: clearMessage ? null : message ?? this.message,
    );
  }
}

/// Shared helper that maps an async action into loading/success/failure states.
class CatalogRunner<T> {
  CatalogRunner(this._read, this._write);

  final CatalogState<T> Function() _read;
  final void Function(CatalogState<T>) _write;

  Future<void> run(Future<T> Function() action) async {
    _write(
      _read().copyWith(status: CatalogViewStatus.loading, clearMessage: true),
    );
    try {
      final data = await action();
      _write(CatalogState<T>(status: CatalogViewStatus.success, data: data));
    } catch (error) {
      _write(
        _read().copyWith(
          status: CatalogViewStatus.failure,
          message: error.toString(),
        ),
      );
    }
  }
}

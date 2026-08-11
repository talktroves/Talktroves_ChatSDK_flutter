/// Base exception for visitor API failures.
class VisitorException implements Exception {
  final String message;
  final int? statusCode;
  final Object? cause;

  const VisitorException(this.message, {this.statusCode, this.cause});

  @override
  String toString() =>
      'VisitorException($message${statusCode != null ? ', statusCode: $statusCode' : ''})';
}

/// Thrown when the visitor session cannot be created or restored.
class VisitorSessionException extends VisitorException {
  const VisitorSessionException(super.message, {super.statusCode, super.cause});
}

/// Thrown when sending a visitor activity fails.
class VisitorActivityException extends VisitorException {
  const VisitorActivityException(
    super.message, {
    super.statusCode,
    super.cause,
  });
}

/// Thrown when polling visitor activities fails.
class VisitorPollingException extends VisitorException {
  const VisitorPollingException(super.message, {super.statusCode, super.cause});
}

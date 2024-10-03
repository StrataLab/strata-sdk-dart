abstract class SimpleTransactionAlgebraError implements Exception {
  SimpleTransactionAlgebraError(this.description);
  final String description;
}

class CannotInitializeProtobuf extends SimpleTransactionAlgebraError {
  CannotInitializeProtobuf(super.description);
}

class InvalidProtobufFile extends SimpleTransactionAlgebraError {
  InvalidProtobufFile(super.description);
}

class CannotSerializeProtobufFile extends SimpleTransactionAlgebraError {
  CannotSerializeProtobufFile(super.description);
}

class NetworkProblem extends SimpleTransactionAlgebraError {
  NetworkProblem(super.description);
}

class UnexpectedError extends SimpleTransactionAlgebraError {
  UnexpectedError(super.description);
}

class CreateTxError extends SimpleTransactionAlgebraError {
  CreateTxError(super.description);
}

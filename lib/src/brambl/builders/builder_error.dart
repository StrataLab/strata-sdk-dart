
/// A generic error type that is returned by the builders when
/// a build is unsuccessful.
///
/// [message] The error message
class BuilderError implements Exception {
  BuilderError(this.message, {this.type, this.exception});

  // TODO: Remove
  // /// A Builder error indicating that an IoTransaction's input
  // /// [SpentTransactionOutput] was not successfully built.
  // ///
  // /// optionally provide [context] to indicate why the build is unsuccessful
  // factory BuilderError.inputBuilder({String? context}) => BuilderError(
  //       context,
  //       type: BuilderErrorType.inputBuilderError,
  //     );

  // /// A Builder error indicating that an IoTransaction's input
  // /// [UnspentTransactionOutput] was not successfully built.
  // ///
  // /// optionally provide [message] to indicate why the build is unsuccessful
  // factory BuilderError.outputBuilder({String? context}) =>
  //     BuilderError(context, type: BuilderErrorType.outputBuilderError);


  /// A Builder error indicating a user input error.
  factory BuilderError.userInputError(String message) =>
      BuilderError(message, type: BuilderErrorType.userInputError);

  /// A Builder error indicating multiple user input errors.
  factory BuilderError.userInputErrors(List<BuilderError> causes) =>
      BuilderError(
          causes.map((e) => e.message).join(", "),
          type: BuilderErrorType.userInputError);

  /// A Builder error indicating a runtime error.
  factory BuilderError.builderRuntimeError(String message, {Exception? cause}) =>
      BuilderError(message, type: BuilderErrorType.builderRuntimeError, exception: cause);


  final String? message;
  final BuilderErrorType? type;
  final Exception? exception;

  @override
  String toString() {
    return 'BuilderError{message: $message, type: $type, exception: $exception}';
  }

}


// todo: figure out if constructor method or factory method is better



enum BuilderErrorType {
  // inputBuilderError,
  // outputBuilderError,
  userInputError,
  builderRuntimeError,
}



class UserInputError extends BuilderError {
  UserInputError(String super.message);
}

class UnableToBuildTransaction extends BuilderError {
  UnableToBuildTransaction(String super.message, Exception cause) : super(exception: cause);
}

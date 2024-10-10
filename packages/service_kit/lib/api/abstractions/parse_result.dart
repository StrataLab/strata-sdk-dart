/// Abstract class for parsing results from Isar to Brambl
abstract class ParseResult<S, T> {
  /// Parse the result from Isar to Brambl
  ///
  /// Internal use only
  List<S> parse(List<T?> results);
}

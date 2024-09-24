import 'package:topl_common/proto/quivr/models/shared.pb.dart';

import '../../../brambldart.dart';

/// Int 128 syntax extensions

extension Int128AsBigInt on Int128 {
  BigInt toBigInt() => value.toBigInt;
}

extension BigIntAsInt128 on BigInt {
  Int128 toInt128() => Int128(value: toTwosComplement());
}

extension LongAsInt128 on int {
  Int128 toInt128() => Int128(value: toBytes);
}

extension Int128Operations on Int128 {
  Int128 operator +(Int128 other) {
    final result = toBigInt() + other.toBigInt();
    return result.toInt128();
  }

  Int128 operator -(Int128 other) {
    final result = toBigInt() - other.toBigInt();
    return result.toInt128();
  }

  bool operator >(Int128 other) {
    return toBigInt() > other.toBigInt();
  }

  bool operator <(Int128 other) {
    return toBigInt() < other.toBigInt();
  }

  bool operator >=(Int128 other) {
    return toBigInt() >= other.toBigInt();
  }

  bool operator <=(Int128 other) {
    return toBigInt() <= other.toBigInt();
  }

  String get show => toBigInt().toString();
}

// dart exclusive shorthand
extension IterableInt128SumExtension on Iterable<Int128> {

  /// Returns the sum of all elements in the iterable.
  Int128 sum() {
    if (isEmpty) {
      throw StateError('Cannot sum elements of an empty iterable');
    }
    return reduce((value, element) => value + element);
  }
}

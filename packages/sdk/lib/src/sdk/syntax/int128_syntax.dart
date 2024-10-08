import 'package:strata_protobuf/google_protobuf.dart';
import 'package:strata_protobuf/strata_protobuf.dart';

import '../../../strata_sdk.dart';

/// Int 128 syntax extensions

extension Int128Syntax on Int128 {
  Int128 get zero => BigInt.zero.toInt128();

  int toInt() => value.toBigInt.toInt();
}

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

  Int128 operator *(Int128 other) {
    final result = toBigInt() * other.toBigInt();
    return result.toInt128();
  }

  double operator /(Int128 other) {
    final a = toBigInt();
    final b = other.toBigInt();

    if (b == BigInt.zero) {
      throw UnsupportedError("Division by zero should be a crime");
    }

    return a / b;
  }

  // discarding remainder
  Int128 operator ~/(Int128 other) {
    final a = toBigInt();
    final b = other.toBigInt();

    if (b == BigInt.zero) {
      throw UnsupportedError("Division by zero should be a crime");
    }

    return (a ~/ b).toInt128();
  }

  Int128 operator %(Int128 other) {
    final thisBigInt = toBigInt();
    final otherBigInt = other.toBigInt();
    final resultBigInt = thisBigInt % otherBigInt;
    return resultBigInt.toInt128();
  }

  String get show => toBigInt().toString();
}

// dart shorthand instead of reduce
extension IterableInt128SumExtension on Iterable<Int128> {
  /// Returns the sum of all elements in the iterable.
  Int128 sum() {
    if (isEmpty) {
      throw StateError('Cannot sum elements of an empty iterable');
    }
    return reduce((value, element) => value + element);
  }
}

extension Uint32Extensions on UInt32Value {
  Int128 toInt128() {
    // Access the underlying integer value
    final int intValue = value;

    // Convert to Int128
    return intValue.toInt128();
  }
}

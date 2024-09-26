import 'package:strata_protobuf/strata_protobuf.dart';

import '../../../brambldart.dart';
import 'merging_ops.dart';

class UserInputValidations {
  /// Validates that the provided [testTxos] contains exactly one address matching [expectedAddr].
  /// Throws [UserInputError] if the validation fails.
  static Txo txosContainsExactlyOneAddress(
    TransactionOutputAddress expectedAddr,
    String expectedLabel,
    List<Txo> testTxos,
  ) {
    final filteredTxos = testTxos.where((txo) => txo.outputAddress == expectedAddr).toList();
    if (filteredTxos.length == 1) {
      return filteredTxos.first;
    } else {
      throw UserInputError("Input TXOs need to contain exactly one txo matching the $expectedLabel");
    }
  }

  /// Validates that the provided [testValue] contains LVLs.
  /// Throws [UserInputError] if the validation fails.
  static LVL isLvls(Value testValue, String testLabel) {
    if (testValue.hasLvl()) {
      return testValue.lvl;
    } else {
      throw UserInputError("$testLabel does not contain LVLs");
    }
  }

  /// Validates that the provided [testValue] contains Group Constructor Tokens.
  /// Throws [UserInputError] if the validation fails.
  static Group isGroup(Value testValue, String testLabel) {
    if (testValue.hasGroup()) {
      return testValue.group;
    } else {
      throw UserInputError("$testLabel does not contain Group Constructor Tokens");
    }
  }

  /// Validates that the provided [testValue] contains Series Constructor Tokens.
  /// Throws [UserInputError] if the validation fails.
  static Series isSeries(Value testValue, String testLabel) {
    if (testValue.hasSeries()) {
      return testValue.series;
    } else {
      throw UserInputError("$testLabel does not contain Series Constructor Tokens");
    }
  }

  /// Validates that the provided [testValue] matches the [expectedValue].
  /// Throws [UserInputError] if the validation fails.
  static void fixedSeriesMatch(
    SeriesId? testValue,
    SeriesId expectedValue,
  ) {
    if (testValue != null && testValue != expectedValue) {
      throw UserInputError("fixedSeries does not match provided Series ID");
    }
  }

  /// Validates that all input locks in [testAddrs] match the expected locks in [expectedAddrs].
  /// Throws [UserInputError] if the validation fails.
  static void allInputLocksMatch(
    Set<LockAddress> testAddrs,
    Set<LockAddress> expectedAddrs,
    String testLabel,
    String expectedLabel,
  ) {
    if (!testAddrs.every(expectedAddrs.contains)) {
      throw UserInputError("every lock in $testLabel must correspond to $expectedLabel");
    }
  }

  /// Validates that the provided [testQuantity] is positive.
  /// Throws [UserInputError] if the validation fails.
  static void positiveQuantity(Int128 testQuantity, String testLabel) {
    if (testQuantity <= Int128().zero) {
      throw UserInputError("$testLabel must be positive");
    }
  }

  /// Validates the minting supply for the provided [desiredQuantity] and [seriesToken].
  /// Throws [UserInputError] if the validation fails.
  static void validMintingSupply(
    Int128 desiredQuantity,
    Series seriesToken,
  ) {
    if (seriesToken.hasTokenSupply()) {
      final tokenSupply = seriesToken.tokenSupply;
      if (desiredQuantity % tokenSupply.toInt128() != Int128().zero) {
        throw UserInputError("quantity to mint must be a multiple of token supply");
      } else if (desiredQuantity > seriesToken.quantity * tokenSupply.toInt128()) {
        throw UserInputError("quantity to mint must be less than total token supply available.");
      }
    }
  }

  /// Validates the transfer supply amount for the provided [desiredQuantity], [allValues], and [transferIdentifier].
  /// Throws [UserInputError] if the validation fails.
  static void validTransferSupplyAmount(
    Int128 desiredQuantity,
    List<Value> allValues,
    ValueTypeIdentifier transferIdentifier,
  ) {
    final testValues = allValues.where((value) => value.typeIdentifier == transferIdentifier).toList();
    final inputQuantity = testValues.fold(Int128().zero, (acc, value) => acc + (value.quantity ?? Int128().zero));
    if (inputQuantity < desiredQuantity) {
      throw UserInputError(
        "All tokens selected to transfer do not have enough funds to transfer. "
        "The desired quantity to transfer is ${desiredQuantity.toBigInt()} but the ${testValues.length} "
        "tokens selected to transfer only have a combined quantity of ${inputQuantity.toBigInt()}.",
      );
    }
  }

  /// Validates the transfer supply for all tokens with the provided [tokenIdentifier] and [testValues].
  /// Throws [UserInputError] if the validation fails.
  static void validTransferSupplyAll(
    ValueTypeIdentifier? tokenIdentifier,
    List<ValueTypeIdentifier> testValues,
  ) {
    if (tokenIdentifier != null) {
      if (!testValues.contains(tokenIdentifier)) {
        throw UserInputError(
            "When tokenIdentifier is provided, there must be some Txos that match the tokenIdentifier.");
      }
    } else {
      if (testValues.isEmpty) {
        throw UserInputError("There must be at least one Txo to transfer.");
      }
    }
  }

  /// Validates that the provided [testValues] do not contain UnknownType.
  /// Throws [UserInputError] if the validation fails.
  static void noUnknownType(List<ValueTypeIdentifier> testValues) {
    if (testValues.any((value) => value is UnknownType)) {
      throw UserInputError("UnknownType tokens are not supported.");
    }
  }

  /// Validates that the provided [testValue] does not have staking registration if it is a Topl type.
  /// Throws [UserInputError] if the validation fails.
  static void toplNoStakingReg(
    ValueTypeIdentifier testValue,
    String testLabel,
  ) {
    if (testValue is ToplType && testValue.stakingRegistration != null) {
      throw UserInputError("If $testLabel is a Topl type, staking registration must be None");
    }
  }

  /// Validates that the provided [testValues] contain enough LVLs to satisfy the [fee] and [transferRequirements].
  /// Throws [UserInputError] if the validation fails.
  static void validFee(
    int fee,
    List<Value> testValues, {
    int transferRequirements = 0,
  }) {
    final totalLvls = testValues
        .where((value) => value.hasLvl())
        .fold<Int128>(Int128().zero, (acc, value) => acc + (value.quantity ?? Int128().zero));
    if (totalLvls.toBigInt() < BigInt.from(fee + transferRequirements)) {
      throw UserInputError("Not enough LVLs in input to satisfy fee");
    }
  }

  /// Validates that all values identified by the [testType] have the same quantity descriptor and are liquid if applicable.
  /// Throws [UserInputError] if the validation fails.
  static void distinctIdentifierQuantityDescriptorLiquid(
    List<Value> values,
    ValueTypeIdentifier testType,
  ) {
    final transferQds =
        values.where((value) => value.typeIdentifier == testType).map((value) => value.quantityDescriptor()).toSet();
    if (transferQds.length > 1) {
      throw UserInputError("All values identified by the ValueTypeIdentifier must have the same quantity descriptor");
    } else {
      final qd = transferQds.first;
      if (qd != QuantityDescriptorType.LIQUID) {
        throw UserInputError("Invalid asset quantity descriptor type. If identifier is an asset, it must be liquid.");
      }
    }
  }

  /// Validates a list of [validations] by calling each function in the list and catching any exceptions.
  static _checkValidations(List<void Function()> validations) {
    final errors = [];

    for (final validation in validations) {
      try {
        validation();
      } catch (e) {
        errors.add(e.toString());
      }
    }

    if (errors.isNotEmpty) {
      throw UserInputError(errors.join('; '));
    }
  }

  /// Validates the parameters for transferring all tokens.
  /// Throws [UserInputError] if the validation fails.
  static void validateTransferAllParams(
    List<Txo> txos,
    LockAddress fromLockAddr,
    int fee,
    ValueTypeIdentifier? tokenIdentifier,
  ) {
    final allValues = txos.map((txo) => txo.transactionOutput.value).toList();

    final validations = [
      () => allInputLocksMatch(
            txos.map((txo) => txo.transactionOutput.address).toSet(),
            {fromLockAddr},
            "the txos",
            "lockPredicateFrom",
          ),
      () => validTransferSupplyAll(tokenIdentifier, allValues.map((value) => value.typeIdentifier).toList()),
      () => noUnknownType(tokenIdentifier != null ? [tokenIdentifier] : []),
      () => validFee(fee, allValues),
    ];

    /// Throws [UserInputError] if the validation fails.
    _checkValidations(validations);
  }

  /// Validates the parameters for transferring a specific amount of a token.
  /// Throws [UserInputError] if the validation fails.
  static void validateTransferAmountParams(
    List<Txo> txos,
    LockAddress fromLockAddr,
    Int128 amount,
    ValueTypeIdentifier transferIdentifier,
    int fee,
  ) {
    final allValues = txos.map((txo) => txo.transactionOutput.value).toList();

    final validations = [
      () => allInputLocksMatch(
            txos.map((txo) => txo.transactionOutput.address).toSet(),
            {fromLockAddr},
            "the txos",
            "lockPredicateFrom",
          ),
      () => positiveQuantity(amount, "quantity to transfer"),
      () => noUnknownType([transferIdentifier]),
      () => validTransferSupplyAmount(amount, allValues, transferIdentifier),
      () => toplNoStakingReg(transferIdentifier, "tokenIdentifier"),
      () => distinctIdentifierQuantityDescriptorLiquid(allValues, transferIdentifier),
      () => validFee(fee, allValues, transferRequirements: transferIdentifier is LvlType ? amount.toInt() : 0),
    ];

    /// Throws [UserInputError] if the validation fails.
    _checkValidations(validations);
  }

  /// Validates the parameters for minting group and series constructor tokens.
  /// Throws [UserInputError] if the validation fails.
  static void validateConstructorMintingParams(
    List<Txo> txos,
    LockAddress fromLockAddr,
    TransactionOutputAddress policyRegistrationUtxo,
    Int128 quantityToMint,
    int fee,
  ) {
    final validations = [
      () => txosContainsExactlyOneAddress(policyRegistrationUtxo, "registrationUtxo", txos),
      () => isLvls(txos.firstWhere((txo) => txo.outputAddress == policyRegistrationUtxo).transactionOutput.value,
          "registrationUtxo"),
      () => allInputLocksMatch(
            txos.map((txo) => txo.transactionOutput.address).toSet(),
            {fromLockAddr},
            "the txos",
            "lockPredicateFrom",
          ),
      () => positiveQuantity(quantityToMint, "quantityToMint"),
      () => validFee(fee, txos.map((txo) => txo.transactionOutput.value).toList()),
    ];

    /// Throws [UserInputError] if the validation fails.
    _checkValidations(validations);
  }

  /// Validates the parameters for minting asset tokens.
  /// Throws [UserInputError] if the validation fails.
  static void validateAssetMintingParams(
    AssetMintingStatement mintingStatement,
    List<Txo> txos,
    Set<LockAddress> locks,
    int fee,
  ) {
    final txoLocks = txos.map((txo) => txo.transactionOutput.address).toSet();

    final validations = [
      () => allInputLocksMatch(txoLocks, locks, "the txos", "a lock in the lock map"),
      () => allInputLocksMatch(locks, txoLocks, "the lock map", "a lock in the txos"),
      () => positiveQuantity(mintingStatement.quantity, "quantity to mint"),
      () => validFee(fee, txos.map((txo) => txo.transactionOutput.value).toList()),
      () {
        // eval group
        final groupTxo = txosContainsExactlyOneAddress(mintingStatement.groupTokenUtxo, "groupTokenUtxo", txos);
        final group = isGroup(groupTxo.transactionOutput.value, "groupTokenUtxo");

        // eval series
        final seriesTxo = txosContainsExactlyOneAddress(mintingStatement.seriesTokenUtxo, "seriesTokenUtxo", txos);
        final series = isSeries(seriesTxo.transactionOutput.value, "groupTokenUtxo");
        positiveQuantity(series.quantity, "quantity of input series constructor tokens");
        validMintingSupply(mintingStatement.quantity, series);
        fixedSeriesMatch(group.fixedSeries, series.seriesId);
      },
    ];

    /// Throws [UserInputError] if the validation fails.
    _checkValidations(validations);
  }

  /// Validates the parameters for merging asset tokens.
  /// Throws [UserInputError] if the validation fails.
  static void validateAssetMergingParams(
    List<TransactionOutputAddress> utxosToMerge,
    List<Txo> txos,
    Set<LockAddress> locks,
    int fee,
  ) {
    final txoLocks = txos.map((txo) => txo.transactionOutput.address).toSet();
    final txosToMerge = txos.where((txo) => utxosToMerge.contains(txo.outputAddress)).toList();

    final validations = [
      () {
        if (utxosToMerge.length != txosToMerge.length) {
          throw UserInputError("All UTXOs to merge must be accounted for in txos");
        }
      },
      () {
        MergingOps.validMerge(txosToMerge).forEach((error) {
          throw UserInputError(error.$1);
        });
      },
      () => allInputLocksMatch(txoLocks, locks, "the txos", "a lock in the lock map"),
      () => allInputLocksMatch(locks, txoLocks, "the lock map", "a lock in the txos"),
      () => validFee(fee, txos.map((txo) => txo.transactionOutput.value).toList()),
    ];

    /// Throws [UserInputError] if the validation fails.
    _checkValidations(validations);
  }
}

import 'dart:typed_data';

import 'package:fixnum/fixnum.dart';
import 'package:protobuf/protobuf.dart';

import 'package:strata_protobuf/google_protobuf.dart' hide Value;
import 'package:strata_protobuf/strata_protobuf.dart';

import '../../common/common.dart';
import '../../utils/extensions.dart';
import '../codecs/address_codecs.dart';
import '../common/contains_evidence.dart';
import '../syntax/syntax.dart';
import 'aggregation_ops.dart';
import 'builder_error.dart';
import 'merging_ops.dart';
import 'user_input_validations.dart';

/// Defines a builder for [IoTransaction]s
abstract class TransactionBuilderApiDefinition {
  /// Builds an unproven attestation for the given predicate
  ///
  /// @param lockPredicate The predicate to use to build the unproven attestation
  /// @return An unproven attestation
  Attestation unprovenAttestation(Lock_Predicate lockPredicate);

  /// Builds a lock address for the given lock
  ///
  /// uses [lock] to build the lock address
  /// and returns a lock address
  LockAddress lockAddress(Lock lock);

  /// Builds a lvl unspent transaction output for the given predicate lock and amount
  ///
  /// Uses the [predicate] and [amount] to build the lvl output
  /// returns an unspent transaction output containing lvls
  Future<UnspentTransactionOutput> lvlOutput(
      Lock_Predicate predicate, Int128 amount);

  /// Builds a lvl unspent transaction output for the given lock address and amount
  ///
  /// uses [lockAddress] and [amount] to build the lvl output
  /// returns an unspent transaction output containing lvls
  Future<UnspentTransactionOutput> lvlOutputWithLockAddress(
      LockAddress lockAddress, Int128 amount);

  /// Builds an unspent transaction output containing group constructor tokens for the given parameters.
  ///
  /// The output is constructed using the provided [lockAddress], [quantity], [groupId], and [fixedSeries].
  ///
  /// Returns the resulting unspent transaction output.
  UnspentTransactionOutput groupOutput(
    LockAddress lockAddress,
    Int128 quantity,
    GroupId groupId, {
    SeriesId? fixedSeries,
  });

  /// Builds an unspent transaction output containing series constructor tokens for the given parameters.
  ///
  /// The output is constructed using the provided [lockAddress], [quantity], [seriesId], [tokenSupply], [fungibility],
  /// and [quantityDescriptor].
  ///
  /// Returns the resulting unspent transaction output.
  UnspentTransactionOutput seriesOutput(
    LockAddress lockAddress,
    Int128 quantity,
    SeriesId seriesId,
    FungibilityType fungibility,
    QuantityDescriptorType quantityDescriptor, {
    int? tokenSupply,
  });

  /// Builds an unspent transaction output containing asset tokens for the given parameters.
  ///
  /// The output is constructed using the provided [lockAddress], [quantity], [groupId], [seriesId], [fungibilityType],
  /// [quantityDescriptorType], [metadata], and [commitment].
  ///
  /// Returns the resulting unspent transaction output.
  UnspentTransactionOutput assetOutput(
    LockAddress lockAddress,
    Int128 quantity,
    GroupId groupId,
    SeriesId seriesId,
    FungibilityType fungibilityType,
    QuantityDescriptorType quantityDescriptorType, {
    Struct? metadata,
    ByteString? commitment,
  });

  /// Builds a datum with default values for a transaction. The schedule is defaulted to use the current timestamp, with
  /// min and max slot being 0 and Long.MaxValue respectively.
  ///
  /// returns a transaction datum
  Datum_IoTransaction datum();

  /// Builds a transaction to transfer the ownership of tokens (optionally identified by [tokenIdentifier]). If
  /// [tokenIdentifier] is provided, only the TXOs matching the identifier will go to the recipient. If it is [null[, then
  /// all tokens provided in [txos] will go to the recipient. Any remaining tokens in [txos] that are not transferred to the
  /// recipient will be transferred to the [changeLockAddress].
  ///
  /// The function takes in the following parameters:
  /// - [txos]: All the TXOs encumbered by the Lock given by [lockPredicateFrom]. These TXOs must contain some token
  ///           matching [tokenIdentifier] (if it is provided) and at least the quantity of LVLs to satisfy the fee, else
  ///           an error will be returned. Any TXOs that contain values of an invalid type, such as UnknownType, will be
  ///           filtered out and won't be included in the inputs.
  /// - [lockPredicateFrom]: The Lock Predicate encumbering the txos.
  /// - [recipientLockAddress]: The LockAddress of the recipient.
  /// - [changeLockAddress]: A LockAddress to send the tokens that are not going to the recipient.
  /// - [fee]: The fee to pay for the transaction. The txos must contain enough LVLs to satisfy this fee.
  /// - [tokenIdentifier]: An optional token identifier to denote the type of token to transfer to the recipient. If
  ///                      [null[, all tokens in [txos] will be transferred to the recipient and [changeLockAddress] will be
  ///                      ignored. This must not be UnknownType.
  ///
  /// Returns an unproven transaction.
  Future<IoTransaction> buildSimpleLvlTransaction(
    List<Txo> lvlTxos,
    Lock_Predicate lockPredicateFrom,
    Lock_Predicate lockPredicateForChange,
    LockAddress recipientLockAddress,
    int amount,
  );

  /// Builds a transaction to transfer the ownership of tokens (optionally identified by [tokenIdentifier]). If
  /// [tokenIdentifier] is provided, only the TXOs matching the identifier will go to the recipient. If it is [null[, then
  /// all tokens provided in [txos] will go to the recipient. Any remaining tokens in [txos] that are not transferred to the
  /// recipient will be transferred to the [changeLockAddress].
  ///
  /// The function takes in the following parameters:
  /// - [txos]: All the TXOs encumbered by the Lock given by [lockPredicateFrom]. These TXOs must contain some token
  ///           matching [tokenIdentifier] (if it is provided) and at least the quantity of LVLs to satisfy the fee, else
  ///           an error will be returned.
  /// - [lockPredicateFrom]: The Lock Predicate encumbering the txos.
  /// - [recipientLockAddress]: The LockAddress of the recipient.
  /// - [changeLockAddress]: A LockAddress to send the tokens that are not going to the recipient.
  /// - [fee]: The fee to pay for the transaction. The txos must contain enough LVLs to satisfy this fee.
  /// - [tokenIdentifier]: An optional token identifier to denote the type of token to transfer to the recipient. If
  ///                      [null[, all tokens in [txos] will be transferred to the recipient and [changeLockAddress] will be
  ///                      ignored.
  ///
  /// Returns an unproven transaction.
  Future<Either<BuilderError, IoTransaction>> buildTransferAllTransaction(
    List<Txo> txos,
    Lock_Predicate lockPredicateFrom,
    LockAddress recipientLockAddress,
    LockAddress changeLockAddress,
    int fee, {
    ValueTypeIdentifier? tokenIdentifier,
  });

  /// Builds a transaction to transfer a certain amount of a specified Token (given by tokenIdentifier). The transaction
  /// will also transfer any other tokens (in the txos) that are encumbered by the same predicate to the change address.
  ///
  /// Note: This function only supports transferring a specific amount of assets (via tokenIdentifier) if their quantity
  /// descriptor type is LIQUID.
  /// Note: This function only support transferring a specific amount of TOPLs (via tokenIdentifier) if their staking
  /// registration is None.
  ///
  /// The function takes in the following parameters:
  /// - [tokenIdentifier]: The Token Identifier denoting the type of token to transfer to the recipient. If this denotes
  /// an Asset Token, the referenced asset's quantity descriptor type must be LIQUID, else an error
  /// will be returned. This must not be UnknownType.
  /// - txos: All the TXOs encumbered by the Lock given by lockPredicateFrom. These TXOs must contain at least the
  /// necessary quantity (given by amount) of the identified Token and at least the quantity of LVLs to
  /// satisfy the fee. Else an error will be returned. Any TXOs that contain values of an invalid type, such
  /// as UnknownType, will be filtered out and won't be included in the inputs.
  /// - [lockPredicateFrom]: The Lock Predicate encumbering the txos
  /// - [amount]: The amount of identified Token to transfer to the recipient
  /// - [recipientLockAddress]: The LockAddress of the recipient
  /// - [changeLockAddress]: A LockAddress to send the tokens that are not going to the recipient
  /// - [fee]: The transaction fee. The txos must contain enough LVLs to satisfy this fee
  ///
  /// Returns an unproven transaction.
  Future<Either<BuilderError, IoTransaction>> buildTransferAmountTransaction(
    ValueTypeIdentifier transferType,
    List<Txo> txos,
    Lock_Predicate lockPredicateFrom,
    int amount,
    LockAddress recipientLockAddress,
    LockAddress changeLockAddress,
    int fee,
  );

  /// Builds a group minting transaction.
  ///
  /// This function constructs a transaction for minting a specified quantity of tokens
  /// according to a given group policy. It performs several steps including validation
  /// of parameters, creation of attestations, and building of transaction inputs and outputs.
  ///
  /// Parameters:
  /// - `txos`: List of transaction outputs to be used as inputs.
  /// - `lockPredicateFrom`: Predicate for the lock from which the transaction is initiated.
  /// - `groupPolicy`: Policy governing the group minting process.
  /// - `quantityToMint`: Quantity of tokens to mint.
  /// - `mintedAddress`: Address to which the minted tokens will be sent.
  /// - `changeAddress`: Address to which any change will be sent.
  /// - `fee`: Transaction fee.
  ///
  /// Returns:
  /// - `Future<Either<BuilderError, IoTransaction>>`: A future that resolves to either a
  ///   `BuilderError` or a successfully constructed `IoTransaction`.
  Either<BuilderError, IoTransaction> buildGroupMintingTransaction(
    List<Txo> txos,
    Lock_Predicate lockPredicateFrom,
    GroupPolicy groupPolicy,
    int quantityToMint,
    LockAddress mintedAddress,
    LockAddress changeAddress,
    int fee,
  );

  /// Builds a simple transaction to mint Series Constructor tokens.
  ///
  /// If successful, the transaction will have one or more inputs (at least the registrationUtxo) and one or more
  /// outputs (at least the minted series constructor tokens). There can be more inputs and outputs if the supplied txos
  /// contain more tokens.
  ///
  /// The function takes in the following parameters:
  /// - [txos]: All the TXOs encumbered by the Lock given by lockPredicateFrom. These TXOs must contain
  /// some LVLs (as specified in the policy), to satisfy the registration fee. Else an error will
  /// be returned. Any TXOs that contain values of an invalid type, such as UnknownType, will be
  /// filtered out and won't be included in the inputs.
  /// - [lockPredicateFrom]: The Predicate Lock that encumbers the funds in the txos. This will be used in
  /// the attestations of the inputs.
  /// - [seriesPolicy]: The series policy for which we are minting constructor tokens. This series policy specifies a
  /// registrationUtxo to be used as an input in this transaction.
  /// - [quantityToMint]: The quantity of constructor tokens to mint
  /// - [mintedAddress]: The LockAddress to send the minted constructor tokens to.
  /// - [changeAddress]: The LockAddress to send the change to.
  /// - [fee]: The transaction fee. The txos must contain enough LVLs to satisfy this fee
  ///
  /// Returns an unproven Series Constructor minting transaction if possible. Else, an error.
  IoTransaction buildSeriesMintingTransaction(
    List<Txo> txos,
    Lock_Predicate lockPredicateFrom,
    SeriesPolicy seriesPolicy,
    int quantityToMint,
    LockAddress mintedAddress,
    LockAddress changeAddress,
    int fee,
  );

  /// Builds an asset minting transaction.
  ///
  /// This function constructs a transaction for minting a specified quantity of assets
  /// according to a given minting statement. It performs several steps including validation
  /// of parameters, creation of attestations, and building of transaction inputs and outputs.
  ///
  /// Parameters:
  /// - `mintingStatement`: Statement describing the asset minting process.
  /// - `txos`: List of transaction outputs to be used as inputs.
  /// - `locks`: Map of lock addresses to their corresponding predicates.
  /// - `fee`: Transaction fee.
  /// - `mintedAssetLockAddress`: Address to which the minted assets will be sent.
  /// - `changeAddress`: Address to which any change will be sent.
  /// - `ephemeralMetadata`: Optional metadata for the minted assets.
  /// - `commitment`: Optional commitment for the minted assets.
  ///
  /// Returns:
  /// - `Future<IoTransaction>`: A future that resolves to a successfully constructed `IoTransaction`.
  IoTransaction buildAssetMintingTransaction(
    AssetMintingStatement mintingStatement,
    List<Txo> txos,
    Map<LockAddress, Lock_Predicate> locks,
    int fee,
    LockAddress mintedAssetLockAddress,
    LockAddress changeAddress, {
    Struct? ephemeralMetadata,
    Uint8List? commitment,
  });

  /// Builds a transaction to merge distinct, but compatible, assets. If successful, the transaction will have one or more
  /// outputs; the merged asset and, optionally, the change. The merged asset will contain the sum of the quantities of the
  /// merged inputs. The change will contain the remaining tokens that were not merged into the merged asset.
  ///
  /// @note The assets to merge must be valid. To be valid, the assets must have the same fungibility type and quantity descriptor
  ///       type. The fungibility type must be one of "GROUP" or "SERIES". If "GROUP", then the assets must share the same Group ID.
  ///       If "SERIES", then the assets must share the same Series ID. Fields such as "commitment" and "ephemeralMetadata" do not
  ///       carryover; if desired, these fields in the merged output can be specified using the "ephemeralMetadata" and "commitment"
  ///       arguments.
  ///
  /// - [utxosToMerge]: The UTXOs to merge. These UTXOs must contain assets that are compatible to merge.
  /// - [txos]: All the TXOs encumbered by the Locks given by locks. These represent the inputs of the transaction.
  /// - [locks]: A mapping of Predicate Locks that encumbers the funds in the txos. This will be used in the attestations of the txos' inputs.
  /// - [fee]: The transaction fee. The txos must contain enough LVLs to satisfy this fee.
  /// - [mergedAssetLockAddress]: The LockAddress to send the merged asset tokens to.
  /// - [changeAddress]: The LockAddress to send any change to.
  /// - [ephemeralMetadata]: Optional ephemeral metadata to include in the merged asset token.
  /// - [commitment]: Optional commitment to include in the merged asset token.
  ///
  /// Returns an unproven asset merge transaction if possible. Else, an error.
  IoTransaction buildAssetMergeTransaction(
    List<TransactionOutputAddress> utxosToMerge,
    List<Txo> txos,
    Map<LockAddress, Lock_Predicate> locks,
    int fee,
    LockAddress mergedAssetLockAddress,
    LockAddress changeAddress, {
    Struct? ephemeralMetadata,
    Uint8List? commitment,
  });
}

class TransactionBuilderApi implements TransactionBuilderApiDefinition {
  const TransactionBuilderApi(this.networkId, this.ledgerId);
  final int networkId;
  final int ledgerId;

  @override
  Future<IoTransaction> buildSimpleLvlTransaction(
    List<Txo> lvlTxos,
    Lock_Predicate lockPredicateFrom,
    Lock_Predicate lockPredicateForChange,
    LockAddress recipientLockAddress,
    int amount,
  ) async {
    final unprovenAttestationToProve = unprovenAttestation(lockPredicateFrom);
    final BigInt totalValues = lvlTxos.fold(BigInt.zero, (acc, x) {
      final y = x.transactionOutput.value;
      return y.hasLvl() && y.lvl.hasQuantity()
          ? acc + y.lvl.quantity.toBigInt()
          : acc;
    });

    final d = datum();
    final lvlOutputForChange = await lvlOutput(
      lockPredicateForChange,
      (totalValues - amount.toBigInt).toInt128(),
    );
    final lvlOutputForRecipient = await lvlOutputWithLockAddress(
      recipientLockAddress,
      Int128(value: amount.toBytes),
    );
    return IoTransaction(
        inputs: lvlTxos
            .map(
              (x) => SpentTransactionOutput(
                address: x.outputAddress,
                attestation: unprovenAttestationToProve,
                value: x.transactionOutput.value,
              ),
            )
            .toList(),
        outputs: totalValues - amount.toBigInt > BigInt.zero
            ? [lvlOutputForRecipient, lvlOutputForChange]
            : [lvlOutputForRecipient],
        datum: d);
  }

  @override
  Future<Either<BuilderError, IoTransaction>> buildTransferAllTransaction(
      List<Txo> txos,
      Lock_Predicate lockPredicateFrom,
      LockAddress recipientLockAddress,
      LockAddress changeLockAddress,
      int fee,
      {ValueTypeIdentifier? tokenIdentifier}) async {
    try {
      // Convert lockPredicateFrom to lockAddress
      final fromLockAddr = lockAddress(Lock()..predicate = lockPredicateFrom);

      // Filter txos to exclude those with UnknownType
      final filteredTxos = txos
          .where((txo) =>
              txo.transactionOutput.value.typeIdentifier is! UnknownType)
          .toList();

      // Validate transfer parameters - can throw exception
      UserInputValidations.validateTransferAllParams(
          filteredTxos, fromLockAddr, fee, tokenIdentifier);

      final stxoAttestation = unprovenAttestation(lockPredicateFrom);

      final d = datum();
      final stxos = _buildStxos(filteredTxos, stxoAttestation);
      final utxosResult = _buildUtxos(filteredTxos, tokenIdentifier, null,
          recipientLockAddress, changeLockAddress, fee);

      // Return IoTransaction
      return Either.right(
          IoTransaction(inputs: stxos, outputs: utxosResult, datum: d));
    } on Exception catch (e) {
      return Either.left(BuilderRuntimeError(
          'Failed to build transfer all transaction. cause: $e', e));
    }
  }

  @override
  Future<Either<BuilderError, IoTransaction>> buildTransferAmountTransaction(
      ValueTypeIdentifier transferType,
      List<Txo> txos,
      Lock_Predicate lockPredicateFrom,
      int amount,
      LockAddress recipientLockAddress,
      LockAddress changeLockAddress,
      int fee) async {
    final fromLockAddr = lockAddress(Lock(predicate: lockPredicateFrom));
    final filteredTxos = txos
        .where(
            (txo) => txo.transactionOutput.value.typeIdentifier is! UnknownType)
        .toList();

    // validate transfer params
    try {
      UserInputValidations.validateTransferAmountParams(
          filteredTxos, fromLockAddr, amount.toInt128(), transferType, fee);
    } on Exception catch (e) {
      return Either.left(BuilderRuntimeError(
          'Failed to build transfer amount transaction. cause: $e', e));
    }

    final stxoAttestation = unprovenAttestation(lockPredicateFrom);
    final d = datum();
    final stxos = _buildStxos(filteredTxos, stxoAttestation);

    final utxos = _buildUtxos(filteredTxos, transferType, amount.toBigInt,
        recipientLockAddress, changeLockAddress, fee);

    return Either.right(IoTransaction(inputs: stxos, outputs: utxos, datum: d));
  }

  List<SpentTransactionOutput> _buildStxos(
      List<Txo> txos, Attestation attestation) {
    return txos
        .map((txo) => SpentTransactionOutput(
              address: txo.outputAddress,
              attestation: attestation,
              value: txo.transactionOutput.value,
            ))
        .toList();
  }

  /// Builds the unspent transaction outputs for the transaction.
  ///
  List<UnspentTransactionOutput> _buildUtxos(
      List<Txo> txos,
      ValueTypeIdentifier?
          transferTypeOpt, // If not provided, then we are transferring all
      BigInt? amount, // If not provided, then we are transferring all
      LockAddress recipientAddress,
      LockAddress changeAddress,
      int fee) {
    try {
      final groupedValues = _applyFee(
          fee,
          txos
              .map((txo) => txo.transactionOutput.value)
              .groupBy((v) => v.typeIdentifier));

      final otherVals = (groupedValues..remove(transferTypeOpt))
          .values
          .expand(DefaultAggregationOps().aggregate)
          .toList();

      // If transferTypeOpt is provided, then we need to calculate what goes to the recipient vs to change
      final (transferValues, changeValues) = transferTypeOpt != null
          ? DefaultAggregationOps()
              .aggregateWithChange(groupedValues[transferTypeOpt] ?? [], amount)
              .withResult(
                  (x) => (x.$1, x.$2 + otherVals)) // add other values to change
          : (<Value>[], <Value>[]);

      final toRecipient = transferValues
          .map((v) =>
              UnspentTransactionOutput(address: recipientAddress, value: v))
          .toList();
      final toChange = changeValues
          .map(
              (v) => UnspentTransactionOutput(address: changeAddress, value: v))
          .toList();

      return toRecipient + toChange;
    } on Exception catch (e) {
      throw BuilderRuntimeError('Failed to build utxos. cause: $e', e);
    }
  }

  /// Apply the fee to the LVL values.
  /// Due to validation, we know that there are enough LVLs in the values to satisfy the fee.
  /// If there are no LVLs, then we don't need to apply the fee.
  ///
  /// [fee] The fee to apply to the LVLs
  /// [values] The values of the transaction's inputs.
  /// returns The values with the LVLs aggregated together and reduced by the fee amount. If there are no LVLs, then
  ///         the values are returned unchanged. In this case, we know that the fee is 0.
  Map<ValueTypeIdentifier, List<BoxValue>> _applyFee(
    int fee,
    Map<ValueTypeIdentifier, List<BoxValue>> values,
  ) {
    values.keys.whereType<LvlType>().forEach((k) {
      final lvlVals = values[k]!;
      final newLvlVal = DefaultAggregationOps()
          .aggregateWithChange(lvlVals, BigInt.from(fee))
          .$2; // accesses change
      if (newLvlVal.isEmpty) {
        values.remove(k);
      } else {
        values[k] = newLvlVal;
      }
    });
    return values;
  }

  @override
  Either<BuilderError, IoTransaction> buildGroupMintingTransaction(
    List<Txo> txos,
    Lock_Predicate lockPredicateFrom,
    GroupPolicy groupPolicy,
    int quantityToMint,
    LockAddress mintedAddress,
    LockAddress changeAddress,
    int fee,
  ) {
    try {
      final registrationLockAddr =
          lockAddress(Lock(predicate: lockPredicateFrom));

      final filteredTxos = txos
          .where((txo) =>
              txo.transactionOutput.value.typeIdentifier is! UnknownType)
          .toList();

      // Validate constructor minting parameters
      try {
        UserInputValidations.validateConstructorMintingParams(
          filteredTxos,
          registrationLockAddr,
          groupPolicy.registrationUtxo,
          quantityToMint.toInt128(),
          fee,
        );
      } catch (e) {
        return Either.left(BuilderError.userInputErrors([e as BuilderError]));
      }

      final stxoAttestation = unprovenAttestation(lockPredicateFrom);
      final d = datum();

      final stxos = _buildStxos(filteredTxos, stxoAttestation);

      final utxoMinted = groupOutput(
          mintedAddress, quantityToMint.toInt128(), groupPolicy.computeId,
          fixedSeries: groupPolicy.fixedSeries);

      final utxoChange = _buildUtxos(
          filteredTxos, null, null, changeAddress, changeAddress, fee);

      // Return IoTransaction
      return Either.right(IoTransaction(
        inputs: stxos,
        outputs: [...utxoChange, utxoMinted],
        datum: d,
        groupPolicies: [Datum_GroupPolicy(event: groupPolicy)],
      ));
    } on Exception catch (e) {
      return Either.left(BuilderRuntimeError(
          'Failed to build group minting transaction. cause: $e', e));
    }
  }

  @override
  IoTransaction buildSeriesMintingTransaction(
      List<Txo> txos,
      Lock_Predicate lockPredicateFrom,
      SeriesPolicy seriesPolicy,
      int quantityToMint,
      LockAddress mintedAddress,
      LockAddress changeAddress,
      int fee) {
    try {
      final registrationLockAddr =
          lockAddress(Lock(predicate: lockPredicateFrom));
      final filteredTxos = txos
          .where((txo) =>
              txo.transactionOutput.value.typeIdentifier is! UnknownType)
          .toList();

      // Validate constructor minting parameters - can throw exception
      UserInputValidations.validateConstructorMintingParams(
          filteredTxos,
          registrationLockAddr,
          seriesPolicy.registrationUtxo,
          quantityToMint.toInt128(),
          fee);

      final stxoAttestation = unprovenAttestation(lockPredicateFrom);
      final stxos = _buildStxos(filteredTxos, stxoAttestation);
      final d = datum();
      final utxoMinted = seriesOutput(
          mintedAddress,
          quantityToMint.toInt128(),
          seriesPolicy.computeId,
          seriesPolicy.fungibility,
          seriesPolicy.quantityDescriptor,
          tokenSupply: seriesPolicy.tokenSupply.value);

      final utxoChange = _buildUtxos(
          filteredTxos, null, null, changeAddress, changeAddress, fee);

      return IoTransaction(
        inputs: stxos,
        outputs: [...utxoChange, utxoMinted],
        datum: d,
        seriesPolicies: [Datum_SeriesPolicy(event: seriesPolicy)],
      );
    } on Exception catch (e) {
      throw BuilderRuntimeError(
          'Failed to build series minting transaction. cause: $e', e);
    }
  }

  /// Converts a list of transaction outputs and locks into a map of attestations.
  ///
  /// This function groups the transaction outputs by their addresses and creates attestations
  /// for each lock predicate. It returns a map where the keys are lists of transaction outputs
  /// and the values are the corresponding attestations.
  ///
  /// Parameters:
  /// - `txos`: List of transaction outputs.
  /// - `locks`: Map of lock addresses to their corresponding predicates.
  ///
  /// Returns:
  /// - `Map<List<Txo>, Attestation>`: A map of transaction outputs to futures of attestations.
  Map<List<Txo>, Attestation> _toAttestationMap(
    List<Txo> txos,
    Map<LockAddress, Lock_Predicate> locks,
  ) {
    final txoMap = txos.groupBy((v) => v.transactionOutput.address);

    return locks.map((key, value) =>
        MapEntry(txoMap[key] ?? [], unprovenAttestation(value)));
  }

  @override
  IoTransaction buildAssetMintingTransaction(
    AssetMintingStatement mintingStatement,
    List<Txo> txos,
    Map<LockAddress, Lock_Predicate> locks,
    int fee,
    LockAddress mintedAssetLockAddress,
    LockAddress changeAddress, {
    Struct? ephemeralMetadata,
    Uint8List? commitment,
  }) {
    final d = datum();

    // Filter txos to exclude those with UnknownType
    final filteredTxos = txos
        .where(
            (txo) => txo.transactionOutput.value.typeIdentifier is! UnknownType)
        .toList();

    // Validate asset minting parameters
    UserInputValidations.validateAssetMintingParams(
      mintingStatement,
      filteredTxos,
      locks.keys.toSet(),
      fee,
    );

    final attestations = _toAttestationMap(filteredTxos, locks);
    final stxos = attestations.entries
        .map((el) => _buildStxos(el.key, el.value))
        .expand((x) => x)
        .toList();

    // Per validation, there is exactly one series token in txos
    final seriesTxo = filteredTxos.firstWhere(
        (txo) => txo.outputAddress == mintingStatement.seriesTokenUtxo);
    final nonSeriesTxo = filteredTxos
        .where((txo) => txo.outputAddress != mintingStatement.seriesTokenUtxo)
        .toList();

    final seriesToken = seriesTxo.transactionOutput.value.series;

    // Per validation, there is exactly one group token in txos
    final groupToken = filteredTxos
        .firstWhere(
            (txo) => txo.outputAddress == mintingStatement.groupTokenUtxo)
        .transactionOutput
        .value
        .group;

    final utxoMinted = assetOutput(
      mintedAssetLockAddress,
      mintingStatement.quantity,
      groupToken.groupId,
      seriesToken.seriesId,
      seriesToken.fungibility,
      seriesToken.quantityDescriptor,
      metadata: ephemeralMetadata,
      commitment: commitment?.asByteString,
    );

    // Adjust seriesTxo
    final inputQuantity = seriesToken.quantity;

    final outputQuantity = seriesToken.hasTokenSupply()
        ? inputQuantity
        : inputQuantity -
            (mintingStatement.quantity ~/ seriesToken.tokenSupply.toInt128());
    final seriesTxoAdjusted = outputQuantity > Int128().zero
        ? [
            (seriesTxo.deepCopy())
              ..transactionOutput.value.series.quantity = outputQuantity
          ]
        : <Txo>[];

    final changeOutputs = _buildUtxos(nonSeriesTxo + seriesTxoAdjusted, null,
        null, changeAddress, changeAddress, fee);

    return IoTransaction(
      inputs: stxos,
      outputs: [...changeOutputs, utxoMinted],
      datum: d,
      mintingStatements: [mintingStatement],
    );
  }

  /// Creates a group output.
  ///
  /// [lockAddress] - The lock address.
  /// [quantity] - The quantity.
  /// [groupId] - The group ID.
  ///
  /// Returns a Future of an UnspentTransactionOutput.
  @override
  UnspentTransactionOutput groupOutput(
    LockAddress lockAddress,
    Int128 quantity,
    GroupId groupId, {
    SeriesId? fixedSeries,
  }) {
    final value = Value(
        group: Group(groupId: groupId, quantity: quantity.value.toInt128));
    return UnspentTransactionOutput(address: lockAddress, value: value);
  }

  /// Creates a series output.
  ///
  /// [lockAddress] - The lock address.
  /// [quantity] - The quantity.
  /// [policy] - The series policy.
  ///
  /// Returns a Future of an UnspentTransactionOutput.
  @override
  UnspentTransactionOutput seriesOutput(
    LockAddress lockAddress,
    Int128 quantity,
    SeriesId seriesId,
    FungibilityType fungibility,
    QuantityDescriptorType quantityDescriptor, {
    int? tokenSupply,
  }) {
    return UnspentTransactionOutput(
        address: lockAddress,
        value: Value(
          series: Series(
            seriesId: seriesId,
            quantity: quantity,
            tokenSupply: UInt32Value(value: tokenSupply),
            quantityDescriptor: quantityDescriptor,
            fungibility: fungibility,
          ),
        ));
  }

  @override
  UnspentTransactionOutput assetOutput(
    LockAddress lockAddress,
    Int128 quantity,
    GroupId groupId,
    SeriesId seriesId,
    FungibilityType fungibilityType,
    QuantityDescriptorType quantityDescriptorType, {
    Struct? metadata,
    ByteString? commitment,
  }) {
    return UnspentTransactionOutput(
      address: lockAddress,
      value: Value(
        asset: Asset(
          groupId: groupId,
          seriesId: seriesId,
          quantity: quantity,
          fungibility: fungibilityType,
          quantityDescriptor: quantityDescriptorType,
          ephemeralMetadata: metadata,
          commitment: commitment?.toBytesValue,
        ),
      ),
    );
  }

  @override
  Future<UnspentTransactionOutput> lvlOutputWithLockAddress(
    LockAddress lockAddress,
    Int128 amount,
  ) async {
    return UnspentTransactionOutput(
      address: lockAddress,
      value: Value(lvl: LVL(quantity: amount)),
    );
  }

  @override
  Future<UnspentTransactionOutput> lvlOutput(
    Lock_Predicate predicate,
    Int128 amount,
  ) async {
    return UnspentTransactionOutput(
      address: LockAddress(
          network: networkId,
          ledger: ledgerId,
          id: LockId(
            value: Lock(predicate: predicate).sizedEvidence.digest.value,
          )),
      value: Value(lvl: LVL(quantity: amount)),
    );
  }

  @override
  LockAddress lockAddress(Lock lock) {
    return LockAddress(
      network: networkId,
      ledger: ledgerId,
      id: LockId(value: lock.sizedEvidence.digest.value),
    );
  }

  /// Creates a datum.
  ///
  /// Returns a Future of a Datum.IoTransaction.
  @override
  Datum_IoTransaction datum() {
    return Datum_IoTransaction(
      event: Event_IoTransaction(
        schedule: Schedule(
            min: Int64.ZERO,
            max: Int64.MAX_VALUE,
            timestamp: Int64(DateTime.now().millisecondsSinceEpoch)),
        metadata: SmallData(),
      ),
    );
  }

  @override
  Attestation unprovenAttestation(Lock_Predicate predicate) {
    return Attestation(
        predicate: Attestation_Predicate(
            lock: predicate,
            responses: List.filled(predicate.challenges.length, Proof())));
  }

  @override
  IoTransaction buildAssetMergeTransaction(
      List<TransactionOutputAddress> utxosToMerge,
      List<Txo> txos,
      Map<LockAddress, Lock_Predicate> locks,
      int fee,
      LockAddress mergedAssetLockAddress,
      LockAddress changeAddress,
      {Struct? ephemeralMetadata,
      Uint8List? commitment}) {
    try {
      final d = datum();

      // Filter txos to exclude those with UnknownType
      final filteredTxos = txos
          .where((txo) =>
              txo.transactionOutput.value.typeIdentifier is! UnknownType)
          .toList();

      UserInputValidations.validateAssetMergingParams(
          utxosToMerge, filteredTxos, locks.keys.toSet(), fee);

      final attestations = _toAttestationMap(filteredTxos, locks);

      final stxos = attestations.entries
          .map((entry) => _buildStxos(entry.key, entry.value))
          .expand((element) => element)
          .toList();

      // Partition filteredTxos into txosToMerge and otherTxos
      final txosToMerge = filteredTxos
          .where((txo) => utxosToMerge.contains(txo.outputAddress))
          .toList();
      final otherTxos = filteredTxos
          .where((txo) => !utxosToMerge.contains(txo.outputAddress))
          .toList();

      // Build utxosChange for the otherTxos
      final utxosChange =
          _buildUtxos(otherTxos, null, null, changeAddress, changeAddress, fee);

      // Merge txosToMerge into a single mergedUtxo
      final mergedUtxo = MergingOps.merge(txosToMerge, mergedAssetLockAddress,
          ephemeralMetadata: ephemeralMetadata,
          commitment: commitment?.asByteString);

      final asm = AssetMergingStatement(
          inputUtxos: utxosToMerge, outputIdx: utxosChange.length);

      // Return the IoTransaction
      return IoTransaction(
        inputs: stxos,
        outputs: [...utxosChange, mergedUtxo],
        datum: d,
        mergingStatements: [asm],
      );
    } on Exception catch (e) {
      throw BuilderError('Failed to build asset merge transaction. cause: $e',
          exception: e);
    }
  }
}

class LockAddressOps {
  LockAddressOps(this.lockAddress);
  final LockAddress lockAddress;

  String toBase58() {
    return AddressCodecs.encode(lockAddress);
  }
}

LockAddressOps lockAddressOps(LockAddress lockAddress) {
  return LockAddressOps(lockAddress);
}

extension Int128IntListExtension on List<int> {
  /// Converts a list of integers to a BigInt instance.
  Int128 get toInt128 => Int128(value: this);
}

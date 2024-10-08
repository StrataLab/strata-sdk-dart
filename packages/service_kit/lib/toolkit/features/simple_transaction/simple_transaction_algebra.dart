import 'package:strata_protobuf/strata_protobuf.dart';
import 'package:strata_sdk/strata_sdk.dart'
    show
        AddressCodecs,
        Either,
        Encoding,
        GenusQueryAlgebra,
        TransactionBuilderApi,
        ValueTypeIdentifier,
        WalletApi,
        WalletStateAlgebra;
import 'package:strata_servicekit/toolkit/features/simple_transaction/simple_transaction_algebra_error.dart';
import 'package:strata_servicekit/toolkit/features/wallet/wallet_management_utils.dart';

abstract class SimpleTransactionAlgebraDefinition {
  Future<Either<SimpleTransactionAlgebraError, IoTransaction>>
      createSimpleTransactionFromParams({
    required String keyfile,
    required String password,
    required String fromFellowship,
    required String fromTemplate,
    int? someFromState,
    String? someChangeFellowship,
    String? someChangeTemplate,
    int? someChangeState,
    LockAddress? someToAddress,
    String? someToFellowship,
    String? someToTemplate,
    required int amount,
    required int fee,
    required ValueTypeIdentifier tokenType,
  });
}

class SimpleTransactionAlgebra extends SimpleTransactionAlgebraDefinition {
  SimpleTransactionAlgebra({
    required this.walletApi,
    required this.walletStateApi,
    required this.utxoAlgebra,
    required this.transactionBuilderApi,
    required this.walletManagementUtils,
  });

  final WalletApi walletApi;
  final WalletStateAlgebra walletStateApi;
  final GenusQueryAlgebra utxoAlgebra;
  final TransactionBuilderApi transactionBuilderApi;
  final WalletManagementUtils walletManagementUtils;

  /// Builds a transaction.
  ///
  /// Throws a [CannotSerializeProtobufFile] if there is a problem serializing the transaction.
  Future<IoTransaction> buildTransaction(
    List<Txo> txos,
    String? someChangeFellowship,
    String? someChangeTemplate,
    int? someChangeState,
    Lock_Predicate predicateFundsToUnlock,
    Lock lockForChange,
    LockAddress recipientLockAddress,
    int amount,
    int fee,
    Indices? someNextIndices,
    KeyPair keyPair,
    ValueTypeIdentifier typeIdentifier,
  ) async {
    try {
      final lockChange = transactionBuilderApi.lockAddress(lockForChange);
      final eitherIoTransaction =
          await transactionBuilderApi.buildTransferAmountTransaction(
        typeIdentifier,
        txos,
        predicateFundsToUnlock,
        amount,
        recipientLockAddress,
        lockChange,
        fee,
      );

      final ioTransaction = eitherIoTransaction.fold((l) => throw l, (r) => r);

      bool nextIndicesExist = false;
      if (someChangeFellowship != null &&
          someChangeTemplate != null &&
          someChangeState != null) {
        nextIndicesExist = !(walletStateApi.getCurrentIndicesForFunds(
              someChangeFellowship,
              someChangeTemplate,
              someChangeState,
            ) ==
            null);
      }

      if (ioTransaction.outputs.length >= 2 && !nextIndicesExist) {
        final lockAddress =
            transactionBuilderApi.lockAddress(lockForChange);
        final vk = someNextIndices != null
            ? walletApi.deriveChildKeys(keyPair, someNextIndices)
            : null;

        walletStateApi.updateWalletState(
          Encoding()
              .encodeToBase58Check(lockForChange.predicate.writeToBuffer()),
          AddressCodecs.encode(lockAddress),
          vk != null ? "ExtendedEd25519" : null,
          vk != null ? Encoding().encodeToBase58(vk.writeToBuffer()) : null,
          someNextIndices!, // TODO(ultimaterex): Figure out why nullable is allowed but we don't have a null path
        );
      }
      return ioTransaction;
    } catch (e) {
      throw CannotSerializeProtobufFile('Cannot write to file');
    }
  }

  @override
  Future<Either<SimpleTransactionAlgebraError, IoTransaction>>
      createSimpleTransactionFromParams({
    required String keyfile,
    required String password,
    required String fromFellowship,
    required String fromTemplate,
    int? someFromState,
    String? someChangeFellowship,
    String? someChangeTemplate,
    int? someChangeState,
    LockAddress? someToAddress,
    String? someToFellowship,
    String? someToTemplate,
    required int amount,
    required int fee,
    required ValueTypeIdentifier tokenType,
  }) async {
    try {
      final keyPair = (await walletManagementUtils.loadKeys(keyfile, password))
          .getOrThrow();
      final someCurrentIndices = walletStateApi.getCurrentIndicesForFunds(
          fromFellowship, fromTemplate, someFromState);
      if (someCurrentIndices == null) {
        return Either.left(CreateTxError('Unable to get current indices'));
      }
      final predicateFundsToUnlock =
          walletStateApi.getLockByIndex(someCurrentIndices);
      if (predicateFundsToUnlock == null) {
        return Either.left(
            CreateTxError('Unable to get lock for current indices'));
      }

      final Indices? someNextIndices;
      if (someChangeFellowship != null &&
          someChangeTemplate != null &&
          someChangeState != null) {
        someNextIndices = walletStateApi.getCurrentIndicesForFunds(
            someChangeFellowship, someChangeTemplate, someChangeState);
      } else {
        someNextIndices =
            walletStateApi.getNextIndicesForFunds(fromFellowship, fromTemplate);
      }
      if (someNextIndices == null) {
        return Either.left(CreateTxError('Unable to get next indices'));
      }

      final changeLock = walletStateApi.getLock(
          fromFellowship, fromTemplate, someNextIndices.z);

      if (changeLock == null) {
        return Either.left(
            CreateTxError('Unable to get lock for next indices'));
      }

      final fromAddress = transactionBuilderApi
          .lockAddress(Lock(predicate: predicateFundsToUnlock));

      final List<Txo> txos;
      try {
        txos = (await utxoAlgebra.queryUtxo(fromAddress: fromAddress))
            .where((x) =>
                !x.transactionOutput.value.hasTopl() &&
                !x.transactionOutput.value.hasUpdateProposal())
            .toList();
      } catch (e) {
        return Either.left(NetworkProblem(e.toString()));
      }

      if (txos.isEmpty) {
        return Either.left(CreateTxError('No LVL txos found'));
      }

      final LockAddress toAddress;
      if (someToAddress != null) {
        toAddress = someToAddress;
      } else if (someToFellowship != null && someToTemplate != null) {
        final addrStr =
            walletStateApi.getAddress(someToFellowship, someToTemplate, null);

        if (addrStr == null) {
          return Either.left(CreateTxError('Unable to determine toAddress'));
        }
        final toAddressOpt = AddressCodecs.decode(addrStr);
        if (toAddressOpt.isRight) {
          toAddress = toAddressOpt.get();
        } else {
          return Either.left(CreateTxError("Invalid toAddress"));
        }
      } else {
        return Either.left(CreateTxError(
            "Either someToAddress or (someToFellowship and someToTemplate) must be provided"));
      }

      final tx = await buildTransaction(
        txos,
        someChangeFellowship,
        someChangeTemplate,
        someChangeState,
        predicateFundsToUnlock,
        changeLock,
        toAddress,
        amount,
        fee,
        someNextIndices,
        keyPair,
        tokenType,
      );

      return Either.right(tx);
    } catch (e) {
      if (e is SimpleTransactionAlgebraError) {
        return Either.left(e);
      } else {
        return Either.left(UnexpectedError(e.toString()));
      }
    }
  }
}

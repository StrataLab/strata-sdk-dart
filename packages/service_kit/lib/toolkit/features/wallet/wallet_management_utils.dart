import 'dart:convert';

import 'package:strata_protobuf/strata_protobuf.dart';
import 'package:strata_sdk/strata_sdk.dart'
    show Either, VaultStore, WalletApi, WalletApiFailure, WalletKeyApiAlgebra;

class WalletManagementUtils {
  WalletManagementUtils({
    required this.walletApi,
    required this.dataApi,
  });
  final WalletApi walletApi;
  final WalletKeyApiAlgebra dataApi;

  Future<Either<Exception, KeyPair>> loadKeys(
      String keyfile, String password) async {
    try {
      final wallet = await readInputFile(keyfile);
      if (wallet.isLeft) {
        return Either.left(wallet.left);
      }
      final keyPair =
          walletApi.extractMainKey(wallet.get(), utf8.encode(password));
      return keyPair;
    } catch (e) {
      return Either.left(
          WalletApiFailure.failedToLoadWallet(context: e.toString()));
    }
  }

  Future<Either<Exception, VaultStore>> readInputFile(String inputFile) async {
    try {
      final vaultStore = await dataApi.getMainKeyVaultStore(inputFile);
      return vaultStore;
    } catch (e) {
      return Either.left(
          WalletApiFailure.failedToLoadWallet(context: e.toString()));
    }
  }
}

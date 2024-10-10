import 'dart:io';

import 'package:strata_sdk/strata_sdk.dart';

class BaseSpec {
  static const testDirectory = './tmp';

  // final storageApi = StorageApi();

  final testDir = Directory(testDirectory);

  // late var walletKeyApi = WalletKeyApi(storageApi.secureStorage);
  // late var walletApi = WalletApi(walletKeyApi);
  // final transactionBuilderApi = const TransactionBuilderApi(
  //   NetworkConstants.privateNetworkId,
  //   NetworkConstants.mainLedgerId,
  // );

  // late var walletStateApi =
  //     WalletStateApi(storageApi.sembast, storageApi.secureStorage);

  mockMainKeyPair() {
    final extendedEd25519Instance = ExtendedEd25519();

    final sk = ExtendedEd25519Intializer(extendedEd25519Instance).random();
    return KeyPair(
      sk,
      extendedEd25519Instance.getVerificationKey(sk as SecretKey),
    );
  }
}

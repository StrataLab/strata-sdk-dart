import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:strata_sdk/strata_sdk.dart'
    show
        Either,
        Unit,
        VaultStore,
        WalletKeyApiAlgebra,
        WalletKeyException,
        WithResultExtension;

class WalletKeyApi implements WalletKeyApiAlgebra {
  const WalletKeyApi(this._storage);

  final FlutterSecureStorage _storage;

  WalletKeyException _vaultStoreDoesNotExist(name) =>
      WalletKeyException.vaultStoreDoesNotExist(
          context: "VaultStore at $name does not exist");

  /// Updates the main key vault store.
  ///
  /// [mainKeyVaultStore] is the new VaultStore to update to.
  /// [name] is the filepath of the VaultStore to update.
  ///
  /// Returns nothing if successful. Throws an exception if the VaultStore does not exist.
  @override
  Future<Either<WalletKeyException, Unit>> updateMainKeyVaultStore(
      VaultStore mainKeyVaultStore, String name) async {
    if (await _storage.containsKey(key: name)) {
      (await saveMainKeyVaultStore(mainKeyVaultStore, name))
          .withResult((res) => res);
      return Either.unit();
    } else {
      return Either.left(_vaultStoreDoesNotExist(name));
    }
  }

  /// Deletes the main key vault store.
  ///
  /// [name] is the filepath of the VaultStore to delete.
  ///
  /// Returns nothing if successful. Throws an exception if the VaultStore does not exist.
  @override
  Future<Either<WalletKeyException, Unit>> deleteMainKeyVaultStore(
      String name) async {
    if (await _storage.containsKey(key: name)) {
      await _storage.delete(key: name);
      return Either.unit();
    } else {
      return Either.left(_vaultStoreDoesNotExist(name));
    }
  }

  /// Persists the main key vault store to disk.
  ///
  /// [mainKeyVaultStore] is the VaultStore to persist.
  /// [name] is the filepath to persist the VaultStore to.
  ///
  /// Returns nothing if successful. If persisting fails due to an underlying cause, returns a WalletKeyException.
  @override
  Future<Either<WalletKeyException, Unit>> saveMainKeyVaultStore(
      VaultStore mainKeyVaultStore, String name) async {
    await _storage.write(
        key: name, value: json.encode(mainKeyVaultStore.toJson()));
    return Either.unit();
  }

  /// Retrieves the main key vault store from disk.
  ///
  /// [name] is the filepath of the VaultStore to retrieve.
  ///
  /// Returns the VaultStore for the Topl Main Secret Key if it exists.
  /// If retrieving fails due to an underlying cause, returns a WalletKeyException.
  @override
  Future<Either<WalletKeyException, VaultStore>> getMainKeyVaultStore(
      String name) async {
    if (await _storage.containsKey(key: name)) {
      return (await _storage.read(key: name)).withResult((res) {
        if (res == null) {
          return Either.left(WalletKeyException.decodeVaultStore(
              context: "Vault store {$name} is empty, thus undecodable"));
        }
        try {
          final vs = VaultStore.fromJson(jsonDecode(res));
          return vs.isRight
              ? Either.right(vs.right)
              : Either.left(WalletKeyException.decodeVaultStore(
                  context: "Vault store {$name} is undecodable, ${vs.left}"));
        } catch (e) {
          return Either.left(WalletKeyException.decodeVaultStore(
              context: "Vault store {$name} is undecodable"));
        }
      });
    } else {
      return Either.left(
          WalletKeyException.vaultStoreDoesNotExist(context: name));
    }
  }

  /// Persists the mnemonic to disk.
  ///
  /// [mnemonic] is the mnemonic to persist.
  /// [mnemonicName] is the filepath to persist the mnemonic to.
  ///
  /// Returns nothing if successful. If persisting fails due to an underlying cause, returns a WalletKeyException.
  @override
  Future<Either<WalletKeyException, Unit>> saveMnemonic(
      List<String> mnemonic, String mnemonicName) async {
    if (await _storage.containsKey(key: mnemonicName)) {
      await _storage.write(key: mnemonicName, value: jsonEncode(mnemonic));
      return Either.unit();
    } else {
      return Either.left(
          WalletKeyException.mnemonicDoesNotExist(context: mnemonicName));
    }
  }
}

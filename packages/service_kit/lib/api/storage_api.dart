import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:sembast_web/sembast_web.dart';

/// Provides an API for managing storage using Isar and FlutterSecureStorage.
class StorageApi {
  StorageApi(this.sembast, this.secureStorage);

  /// Creates a new instance of StorageApi.
  ///
  /// If [sembast] and [secureStorage] are not provided, they will be initialized
  /// with default settings.
  static Future<StorageApi> init(
      {Database? sembast, FlutterSecureStorage? secureStorage}) async {
    return StorageApi(
        sembast ?? await databaseFactoryWeb.openDatabase("wallet"),
        secureStorage ?? const FlutterSecureStorage());
  }

  final Database sembast;
  final FlutterSecureStorage secureStorage;
}

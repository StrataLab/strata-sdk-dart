import 'package:sembast/sembast.dart';
import 'package:strata_sdk/strata_sdk.dart' as sdk;
import 'package:strata_service_kit/models/fellowship.dart';

class FellowshipStorageApi implements sdk.FellowshipStorageAlgebra {
  FellowshipStorageApi(this._instance);

  final Database _instance;

  @override
  Future<int> addFellowship(sdk.WalletFellowship walletEntity) async {
    try {
      final latest = await fellowshipsStore.findFirst(_instance,
          finder: Finder(sortOrders: [SortOrder("x", false)]));
      final x = latest != null ? ((latest["x"]! as int) + 1) : 0;
      return fellowshipsStore.add(
          _instance, Fellowship(x: x, name: walletEntity.name).toSembast);
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<List<sdk.WalletFellowship>> findFellowships(
      List<sdk.WalletFellowship> walletEntities) async {
    try {
      final walletFellowships = await fellowshipsStore
          .records(walletEntities.map((c) => c.xIdx))
          .get(_instance);

      return walletFellowships
          .map((json) =>
              sdk.WalletFellowship(json!["x"]! as int, json["name"]! as String))
          .toList();
    } catch (e) {
      rethrow;
    }
  }
}

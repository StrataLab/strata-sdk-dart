import 'package:sembast/sembast.dart';
import 'package:strata_sdk/strata_sdk.dart' as sdk;
import 'package:strata_service_kit/models/template.dart';

class TemplateStorageApi implements sdk.TemplateStorageAlgebra {
  TemplateStorageApi(this._instance);

  final Database _instance;

  @override
  Future<int> addTemplate(sdk.WalletTemplate walletTemplate) async {
    final latest = await templatesStore.findFirst(_instance,
        finder: Finder(sortOrders: [SortOrder("y", false)]));
    final y = latest != null ? ((latest["y"]! as int) + 1) : 0;
    final template = Template(
        y: y, lock: walletTemplate.lockTemplate, name: walletTemplate.name);
    try {
      return templatesStore.add(_instance, template.toSembast);
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<List<sdk.WalletTemplate>> findTemplates() async {
    try {
      final result = await templatesStore.find(_instance);

      return result
          .map((json) => sdk.WalletTemplate(
              json.key, json["template"]! as String, json["lock"]! as String))
          .toList();
    } catch (e) {
      rethrow;
    }
  }
}

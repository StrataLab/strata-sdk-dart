import 'package:sembast/sembast.dart';

class Fellowship {
  Fellowship({required this.x, required this.name});

  final int x;
  final String name;

  Map<String, Object?> get toSembast => {
        "x": x,
        "name": name,
      };
}

final fellowshipsStore = intMapStoreFactory.store("fellowships");

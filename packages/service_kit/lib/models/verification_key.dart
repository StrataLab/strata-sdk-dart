import 'package:sembast/sembast.dart';

class VerificationKey {
  VerificationKey({required this.x, required this.y, required this.vks});

  late int x;
  late int y;
  late List<String> vks;

  Map<String, Object?> get toSembast => {
        "x": x,
        "y": y,
        "vks": vks,
      };
}

final verificationKeysStore = intMapStoreFactory.store("verificationKeys");

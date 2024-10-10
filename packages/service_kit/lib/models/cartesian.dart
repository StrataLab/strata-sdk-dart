import 'package:sembast/sembast.dart';

class Cartesian {
  Cartesian(
      {required this.x,
      required this.y,
      required this.z,
      required this.lockPredicate,
      required this.address,
      this.routine,
      this.vk});

  final int x;
  final int y;
  final int z;
  final String lockPredicate;
  final String address;
  String? routine;
  String? vk;

  Map<String, Object?> get toSembast => {
        "x": x,
        "y": y,
        "z": z,
        "lockPredicate": lockPredicate,
        "address": address,
        "routine": routine,
        "vk": vk,
      };
}

final cartesiansStore = intMapStoreFactory.store("cartesians");

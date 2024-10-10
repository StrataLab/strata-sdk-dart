import 'package:sembast/sembast.dart';

class Digest {
  Digest(
      {required this.digestEvidence,
      required this.preimageInput,
      required this.preimageSalt});

  final String digestEvidence;
  final String preimageInput;
  final String preimageSalt;

  Map<String, Object?> get toSembast => {
        "digestEvidence": digestEvidence,
        "preimageInput": preimageInput,
        "preimageSalt": preimageSalt,
      };
}

final digestsStore = intMapStoreFactory.store("digests");

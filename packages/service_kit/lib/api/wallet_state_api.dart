import 'dart:convert';
import 'dart:typed_data';

import 'package:fixnum/fixnum.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:sembast/sembast.dart';
import 'package:strata_protobuf/strata_protobuf.dart' as m;
import 'package:strata_sdk/strata_sdk.dart'
    show
        AddressCodecs,
        Either,
        Encoding,
        ExtendedEd25519,
        HeightTemplate,
        IntExtension,
        LockTemplate,
        PredicateTemplate,
        SCrypt,
        SignatureTemplate,
        SizedEvidence,
        WalletApi,
        WalletStateAlgebra;
import 'package:strata_service_kit/api/wallet_key_api.dart';
import 'package:strata_service_kit/models/cartesian.dart';
import 'package:strata_service_kit/models/digest.dart';
import 'package:strata_service_kit/models/fellowship.dart';
import 'package:strata_service_kit/models/template.dart';
import 'package:strata_service_kit/models/verification_key.dart' as sk;
import 'package:strata_service_kit/models/verification_key.dart';

/// An implementation of the WalletStateAlgebra that uses a database to store state information.

class WalletStateApi implements WalletStateAlgebra {
  WalletStateApi(
    this._instance,
    this._secureStorage, {
    ExtendedEd25519? extendedEd25519,
    SCrypt? kdf,
  }) : api = WalletApi(
          WalletKeyApi(_secureStorage),
          extendedEd25519Instance: extendedEd25519,
          kdfInstance: kdf,
        );

  final Database _instance;
  // ignore: unused_field
  final FlutterSecureStorage _secureStorage;
  final WalletApi api;

  @override
  Future<void> initWalletState(
      int networkId, int ledgerId, m.VerificationKey vk) async {
    final defaultTemplate = PredicateTemplate(
      [SignatureTemplate("ExtendedEd25519", 0)],
      1,
    );

    final genesisTemplate = PredicateTemplate(
      [HeightTemplate('header', 1.toInt64, Int64.MAX_VALUE)],
      1,
    );

    // Create parties
    await fellowshipsStore.add(
        _instance, Fellowship(x: 0, name: 'nofellowship').toSembast);
    await fellowshipsStore.add(
        _instance, Fellowship(x: 1, name: 'self').toSembast);

    // Create templates
    await templatesStore.add(
        _instance,
        Template(
                y: 1,
                name: 'default',
                lock: jsonEncode(defaultTemplate.toJson()))
            .toSembast);
    await templatesStore.add(
        _instance,
        Template(
                y: 2,
                name: 'genesis',
                lock: jsonEncode(genesisTemplate.toJson()))
            .toSembast);

    // Create verification keys
    await verificationKeysStore.add(
        _instance,
        sk.VerificationKey(
          x: 1,
          y: 1,
          vks: [Encoding().encodeToBase58Check(vk.writeToBuffer())],
        ).toSembast); // TODO(ultimaterex): figure out if encoding to stringbase 58 is better
    await verificationKeysStore.add(
        _instance,
        sk.VerificationKey(
          x: 0,
          y: 2,
          vks: [],
        ).toSembast);

    final defaultSignatureLock = getLock("self", "default", 1)!; // unsafe
    final signatureLockAddress = m.LockAddress(
        network: networkId,
        ledger: ledgerId,
        id: m.LockId(
            value: defaultSignatureLock.predicate.sizedEvidence.digest.value));

    final childVk = api.deriveChildVerificationKey(vk, 1);
    final genesisHeightLock = getLock("nofellowship", "genesis", 1)!; // unsafe
    final heightLockAddress = m.LockAddress(
        network: networkId,
        ledger: ledgerId,
        id: m.LockId(
            value: genesisHeightLock.predicate.sizedEvidence.digest.value));

    // Create cartesian coordinates
    await cartesiansStore.add(
        _instance,
        Cartesian(
          x: 1,
          y: 1,
          z: 1,
          lockPredicate: Encoding().encodeToBase58Check(
              defaultSignatureLock.predicate.writeToBuffer()),
          address: AddressCodecs.encode(signatureLockAddress),
          routine: 'ExtendedEd25519',
          vk: Encoding().encodeToBase58Check(childVk.writeToBuffer()),
        ).toSembast);

    await cartesiansStore.add(
        _instance,
        Cartesian(
          x: 0,
          y: 2,
          z: 1,
          lockPredicate: Encoding()
              .encodeToBase58Check(genesisHeightLock.predicate.writeToBuffer()),
          address: AddressCodecs.encode(heightLockAddress),
        ).toSembast);
  }

  @override
  m.Indices? getIndicesBySignature(
      m.Proposition_DigitalSignature signatureProposition) {
    final result = cartesiansStore.findSync(_instance,
        finder: Finder(
            filter: Filter.and([
          Filter.equals("routine", signatureProposition.routine),
          Filter.equals(
              "vk",
              Encoding().encodeToBase58Check(
                  signatureProposition.verificationKey.writeToBuffer())),
        ])));

    if (result.isEmpty) return null;
    return m.Indices(
      x: result.first["x"] as int?,
      y: result.first["y"] as int?,
      z: result.first["z"] as int?,
    );
  }

  @override
  m.Lock_Predicate? getLockByIndex(m.Indices indices) {
    final result = cartesiansStore.findSync(_instance,
        finder: Finder(
            filter: Filter.and([
          Filter.equals("x", indices.x),
          Filter.equals("y", indices.y),
          Filter.equals("z", indices.z),
        ])));

    if (result.isEmpty) return null;
    return m.Lock_Predicate.fromBuffer(Encoding()
        .decodeFromBase58Check(result.first["lockPredicate"]! as String)
        .get());
  }

  @override
  m.Lock_Predicate? getLockByAddress(String lockAddress) {
    final result = cartesiansStore.findSync(_instance,
        finder: Finder(
            filter: Filter.and([
          Filter.equals("address", lockAddress),
        ])));

    if (result.isEmpty) return null;
    return m.Lock_Predicate.fromBuffer(Encoding()
        .decodeFromBase58Check(result.first["lockPredicate"]! as String)
        .get());
  }

  @override
  Future<void> updateWalletState(String lockPredicate, String lockAddress,
      String? routine, String? vk, m.Indices indices) async {
    await cartesiansStore.add(
      _instance,
      Cartesian(
              x: indices.x,
              y: indices.y,
              z: indices.z,
              lockPredicate: lockPredicate,
              address: lockAddress,
              routine: routine,
              vk: vk)
          .toSembast,
    );
  }

  @override
  m.Indices? getNextIndicesForFunds(String fellowship, String template) {
    final fellowshipResult = fellowshipsStore.findFirstSync(_instance,
        finder: Finder(filter: Filter.equals("name", fellowship)));

    final templateResult = templatesStore.findFirstSync(_instance,
        finder: Finder(filter: Filter.equals("name", template)));

    if (fellowshipResult != null && templateResult != null) {
      final x = fellowshipResult["x"]! as int;
      final y = templateResult["y"]! as int;
      final cartesianResult = cartesiansStore.findFirstSync(_instance,
          finder: Finder(
              filter: Filter.and([
                Filter.equals("x", x),
                Filter.equals("y", y),
              ]),
              sortOrders: [SortOrder("z", false)]));

      if (cartesianResult != null) {
        final z = (cartesianResult["z"]! as int) + 1;
        return m.Indices(x: x, y: y, z: z);
      } else {
        return m.Indices(x: x, y: y, z: 1);
      }
    }

    return null;
  }

  bool validateFellowship(String fellowship) {
    final result = fellowshipsStore.findFirstSync(_instance,
        finder: Finder(
            filter: Filter.and([
          Filter.equals("name", fellowship),
        ])));
    return result != null;
  }

  bool validateTemplate(String template) {
    final result = templatesStore.findFirstSync(_instance,
        finder: Finder(
            filter: Filter.and([
          Filter.equals("name", template),
        ])));
    return result != null;
  }

  @override
  Either<String, m.Indices> validateCurrentIndicesForFunds(
      String fellowship, String template, int? someState) {
    // ignore: unused_local_variable
    final p = validateFellowship(fellowship);
    // ignore: unused_local_variable
    final c = validateTemplate(template);
    final indices = getCurrentIndicesForFunds(fellowship, template, someState);

    if (indices == null) return Either.left('Indices not found');
    return Either.right(indices);
  }

  @override
  String? getAddress(String fellowship, String template, int? someInteraction) {
    final fellowshipResult = fellowshipsStore.findFirstSync(_instance,
        finder: Finder(filter: Filter.equals("name", fellowship)));

    final templateResult = templatesStore.findFirstSync(_instance,
        finder: Finder(filter: Filter.equals("name", template)));

    if (fellowshipResult != null && templateResult != null) {
      final x = fellowshipResult["x"]! as int;
      final y = templateResult["y"]! as int;
      final cartesianResult = cartesiansStore.findFirstSync(_instance,
          finder: Finder(
            filter: Filter.and([
              Filter.equals("x", x),
              Filter.equals("y", y),
              Filter.equals("z", someInteraction ?? 1),
            ]),
          ));

      if (cartesianResult == null) return null;
      return cartesianResult["address"]! as String;
    }
    return null;
  }

  @override
  m.Indices? getCurrentIndicesForFunds(
      String fellowship, String template, int? someState) {
    final fellowshipResult = fellowshipsStore.findFirstSync(_instance,
        finder: Finder(filter: Filter.equals("name", fellowship)));

    final templateResult = templatesStore.findFirstSync(_instance,
        finder: Finder(filter: Filter.equals("name", template)));

    if (fellowshipResult != null && templateResult != null) {
      final x = fellowshipResult["x"]! as int;
      final y = templateResult["y"]! as int;
      final cartesianResult = cartesiansStore.findFirstSync(_instance,
          finder: Finder(
            filter: Filter.and([
              Filter.equals("x", x),
              Filter.equals("y", y),
              Filter.equals("z", someState ?? 0),
            ]),
          ));

      if (cartesianResult != null) {
        final z = (cartesianResult["z"]! as int) + 1;
        return m.Indices(x: x, y: y, z: z);
      } else {
        return m.Indices(x: x, y: y, z: 1);
      }
    }
    return null;
  }

  @override
  m.Indices? setCurrentIndices(
      String fellowship, String template, int interaction) {
    final fellowshipResult = fellowshipsStore.findFirstSync(_instance,
        finder: Finder(filter: Filter.equals("name", fellowship)));

    final templateResult = templatesStore.findFirstSync(_instance,
        finder: Finder(filter: Filter.equals("name", template)));

    // TODO: Incorrect implementation
    if (fellowshipResult != null && templateResult != null) {
      cartesiansStore.add(
          _instance,
          Cartesian(
            x: fellowshipResult["x"]! as int,
            y: templateResult["y"]! as int,
            z: interaction,
            lockPredicate: "", // TODO
            address: "", // TODO
          ).toSembast);
    }
    return null;
  }

  @override
  String getCurrentAddress() {
    final cartesianResult = cartesiansStore.findFirstSync(
      _instance,
      finder: Finder(
        filter: Filter.and([
          Filter.equals("x", 1),
          Filter.equals("y", 1),
        ]),
        sortOrders: [SortOrder("z", false)],
      ),
    );

    if (cartesianResult != null) return cartesianResult["address"]! as String;
    throw Exception('No address found');
  }

  @override
  m.Preimage? getPreimage(m.Proposition_Digest digestProposition) {
    final result = digestsStore.findFirstSync(_instance,
        finder: Finder(
          filter: Filter.equals(
              "digestEvidence",
              Encoding().encodeToBase58Check(Uint8List.fromList(
                  digestProposition.sizedEvidence.digest.value))),
        ));

    if (result != null) {
      return m.Preimage(
          input: Encoding()
              .decodeFromBase58Check(result["preimageInput"]! as String)
              .getOrThrow(),
          salt: Encoding()
              .decodeFromBase58Check(result["preimageSalt"]! as String)
              .getOrThrow());
    }
    return null;
  }

  @override
  void addPreimage(
      m.Preimage preimage, m.Proposition_Digest digestProposition) {
    digestsStore.add(
      _instance,
      Digest(
        digestEvidence: Encoding().encodeToBase58Check(
            Uint8List.fromList(digestProposition.sizedEvidence.digest.value)),
        preimageInput:
            Encoding().encodeToBase58Check(Uint8List.fromList(preimage.input)),
        preimageSalt:
            Encoding().encodeToBase58Check(Uint8List.fromList(preimage.salt)),
      ).toSembast,
    );
  }

  @override
  Future<void> addEntityVks(
      String fellowship, String template, List<String> entities) async {
    final fellowshipResult = fellowshipsStore.findFirstSync(_instance,
        finder: Finder(filter: Filter.equals("name", fellowship)));

    final templateResult = templatesStore.findFirstSync(_instance,
        finder: Finder(filter: Filter.equals("name", template)));

    if (fellowshipResult != null && templateResult != null) {
      final x = fellowshipResult["x"]! as int;
      final y = templateResult["y"]! as int;
      await verificationKeysStore.add(
        _instance,
        sk.VerificationKey(
          x: x,
          y: y,
          vks: entities,
        ).toSembast,
      );
    }
  }

  @override
  List<String>? getEntityVks(String fellowship, String template) {
    final fellowshipResult = fellowshipsStore.findFirstSync(_instance,
        finder: Finder(filter: Filter.equals("name", fellowship)));

    final templateResult = templatesStore.findFirstSync(_instance,
        finder: Finder(filter: Filter.equals("name", template)));

    if (fellowshipResult != null && templateResult != null) {
      final x = fellowshipResult["x"]! as int;
      final y = templateResult["y"]! as int;
      final verificationKeyResult =
          verificationKeysStore.findFirstSync(_instance,
              finder: Finder(
                filter: Filter.and([
                  Filter.equals("x", x),
                  Filter.equals("y", y),
                ]),
              ));

      if (verificationKeyResult != null) {
        return (verificationKeyResult["vks"]! as List).cast<String>();
      }
    }

    return null;
  }

  @override
  Future<void> addNewLockTemplate(
      String template, LockTemplate lockTemplate) async {
    final latest = await templatesStore.findFirst(_instance,
        finder: Finder(sortOrders: [SortOrder("y", false)]));
    final y = latest != null ? ((latest["y"]! as int) + 1) : 0;
    await templatesStore.add(
      _instance,
      Template(
        y: y,
        name: template,
        lock: jsonEncode(lockTemplate.toJson()),
      ).toSembast,
    );
  }

  @override
  LockTemplate? getLockTemplate(String template) {
    final templateResult = templatesStore.findFirstSync(_instance,
        finder: Finder(filter: Filter.equals("name", template)));

    if (templateResult == null) return null;
    return LockTemplate.fromJson(jsonDecode(templateResult["lock"]! as String));
  }

  @override
  m.Lock? getLock(String fellowship, String template, int nextState) {
    final lockTemplate = getLockTemplate(template);
    final entityVks = getEntityVks(fellowship, template);

    if (lockTemplate == null || entityVks == null) return null;

    final childVks = entityVks.map((vk) {
      final fullKey = m.VerificationKey.fromBuffer(
          Encoding().decodeFromBase58Check(vk).get());
      return api.deriveChildVerificationKey(fullKey, nextState);
    });
    final res = lockTemplate.build(childVks.toList());

    return res.isRight ? res.right! : null;
  }
}

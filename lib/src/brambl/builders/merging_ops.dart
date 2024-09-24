import 'dart:typed_data';

import 'package:brambldart/brambldart.dart';
import 'package:brambldart/src/crypto/accumulators/accumulators.dart';
import 'package:convert/convert.dart';
import 'package:topl_common/proto/brambl/models/address.pb.dart';
import 'package:topl_common/proto/brambl/models/box/asset.pb.dart';
import 'package:topl_common/proto/brambl/models/box/value.pb.dart';
import 'package:topl_common/proto/brambl/models/identifier.pb.dart';
import 'package:topl_common/proto/brambl/models/transaction/unspent_transaction_output.pb.dart';
import 'package:topl_common/proto/genus/genus_models.pb.dart';
import 'package:topl_common/proto/google/protobuf/struct.pb.dart';

import '../../crypto/accumulators/merkle/merkle_tree.dart';

class MergingOps {
  static const int MaxDataLength = 15360;

  // We strip ephemeral metadata and commitment because when splitting the alloy in the future, these fields may be different in the outputs.
  static Uint8List getPreimageBytes(Value_Asset asset) {
    final cleared = asset
      ..clearEphemeralMetadata()
      ..clearCommitment();
    return ContainsImmutable.assetValue(cleared).immutableBytes.value.toUint8List();
  }

  // Get alloy preimages, sort, then construct merkle proof using Sha256.
  static ByteString getAlloy(List<Value_Asset> values) {
    final List<Uint8List> preimages = values.map(getPreimageBytes).toList();
    preimages.sort((p1, p2) {
      final hex1 = hex.encode(p1);
      final hex2 = hex.encode(p2);
      return hex1.compareTo(hex2);
    });

    // SHA, Digest32 is used for the hash function -> SHA256
    final MerkleTree merkleTree = MerkleTree.fromLeafs(
      preimages.map((e) => LeafData(e)).toList(),
      SHA256(),
    );

    return merkleTree.rootHash.bytes.byteString;
  }

  // Precondition: the values represent a valid merge
  static UnspentTransactionOutput merge(
    List<Txo> values,
    LockAddress mergedAssetLockAddress,
    Struct ephemeralMetadata,
    ByteString? commitment,
  ) {
    final quantity = values.map((v) => v.transactionOutput.value.asset.quantity).sum();

    final bool isGroupFungible = values.first.transactionOutput.value.asset.fungibility == FungibilityType.GROUP;

    return UnspentTransactionOutput(
        address: mergedAssetLockAddress,
        value: Value_Asset(
          groupId: isGroupFungible
              ? GroupId(value: values.first.transactionOutput.value.asset.typeIdentifier.groupIdOrAlloy.value)
              : null,
          seriesId: !isGroupFungible
              ? SeriesId(value: values.first.transactionOutput.value.asset.typeIdentifier.seriesIdOrAlloy.value)
              : null,
          groupAlloy: !isGroupFungible
              ? getAlloy(values.map((v) => v.transactionOutput.value.asset).toList()).toBytesValue
              : null,
          seriesAlloy: isGroupFungible
              ? getAlloy(values.map((v) => v.transactionOutput.value.asset).toList()).toBytesValue
              : null,
          quantity: quantity,
          fungibility: values.first.transactionOutput.value.asset.fungibility,
          quantityDescriptor: values.first.transactionOutput.value.asset.quantityDescriptor,
          ephemeralMetadata: ephemeralMetadata,
          commitment: commitment?.toBytesValue,
        ).asBoxVal());
  }

  // TODO: figure out what exceptions to return for these here, for now using default Exception
  static _insufficientAssetsValidation(List<Txo> values) {
    if (values.length >= 2) return;
    throw Exception("There must be at least 2 UTXOs to merge");
  }

  static _noDuplicatesValidation(List<Txo> values) {
    if (values.map((v) => v.outputAddress).toSet().length == values.length) return;
    throw Exception("UTXOs to merge must not have duplicates");
  }

  static distinctIdentifierValidation(List<ValueTypeIdentifier> values) {
    if (values.toSet().length == values.length) return;
    throw Exception("UTXOs to merge must all be distinct (per type identifier)");
  }

  static validFungibilityTypeValidation(List<Txo> values) {
    final fungibility = values.first.transactionOutput.value.asset.fungibility;
    final typeIdentifier = values.first.transactionOutput.value.asset.typeIdentifier;

    if (fungibility == FungibilityType.GROUP_AND_SERIES) {
      throw Exception("Assets to merge must not have Group_And_Series fungibility type");
    } else if (fungibility == FungibilityType.SERIES) {
      final seriesIdOrAlloy = typeIdentifier.seriesIdOrAlloy;
      if (!values
          .skip(1)
          .every((v) => v.transactionOutput.value.asset.typeIdentifier.seriesIdOrAlloy == seriesIdOrAlloy)) {
        throw Exception("Merging Series fungible assets must share a series ID");
      }
    } else if (fungibility == FungibilityType.GROUP) {
      final groupIdOrAlloy = typeIdentifier.groupIdOrAlloy;
      if (!values
          .skip(1)
          .every((v) => v.transactionOutput.value.asset.typeIdentifier.groupIdOrAlloy == groupIdOrAlloy)) {
        throw Exception("Merging Group fungible assets must share a group ID");
      }
    } else {
      throw Exception("Merging Group or Series fungible assets do not have valid AssetType identifiers");
    }
  }

  static _validIdentifiersValidation(List<Txo> values) {
    try {
      final identifiers = values.map((v) => v.transactionOutput.value.typeIdentifier).toList();
      if (identifiers.every((id) => id is AssetType)) {
        distinctIdentifierValidation(identifiers);
        validFungibilityTypeValidation(values);
      } else {
        throw Exception("UTXOs to merge must all be assets");
      }
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  static _sameFungibilityTypeValidation(List<Txo> values) {
    final fungibility = values.first.transactionOutput.value.asset.fungibility;
    if (!values.every((v) => v.transactionOutput.value.asset.fungibility == fungibility)) {
      throw Exception("Assets to merge must all share the same fungibility type");
    }
  }

  static _sameQuantityDescriptorValidation(List<Txo> values) {
    final quantityDescriptor = values.first.transactionOutput.value.asset.quantityDescriptor;
    if (!values.every((v) => v.transactionOutput.value.asset.quantityDescriptor == quantityDescriptor)) {
      throw Exception("Merging assets must all share the same Quantity Descriptor Type");
    }
  }

  static final List<Function(List<Txo> values)> _validators = [
    _insufficientAssetsValidation,
    _noDuplicatesValidation,
    _validIdentifiersValidation,
    _sameFungibilityTypeValidation,
    _sameQuantityDescriptorValidation,
  ];

  /// Validates the UTXOs to be merged
  ///
  /// Returns a list of exceptions [(String, Error)] if the merge is invalid
  static List<(String, Exception)> validMerge(List<Txo> values) {
    final errors = <(String, Exception)>[];
    for (final validator in _validators) {
      try {
        validator(values);
      } on Exception catch (e) {
        errors.add((e.toString(), e));
      }
    }
    return errors;
  }
}

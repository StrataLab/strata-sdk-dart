import 'package:protobuf/protobuf.dart';
import 'package:strata_protobuf/strata_protobuf.dart';

import '../../../strata_sdk.dart';

// Long -> longSignable -> longSignableEvidence -> longSignableEvidenceId
// Long -> longSignable -> longSignableEvidence -> longSingableEvidenceSignable -> longSingableEvidenceSignableEvidence
// Object -> Signable -> Evidence -> Identifier -> Address -> KnownIdentifier

// Topl: TObject -> TSignable -> TEvidence -> TIdentifier -> TAddress -> TKnownIdentifier
// DAML: DObject -> DSignable -> DEvidence (==TEvidence) -> TSignable -> TEvidence -> TIdentifier -> TAddress -> TKnownIdentifier

class ContainsSignable {
  const ContainsSignable(this.signableBytes);

  factory ContainsSignable.empty() {
    return ContainsSignable(SignableBytes());
  }

  factory ContainsSignable.immutable(ImmutableBytes bytes) {
    return ContainsSignable(SignableBytes(value: bytes.value));
  }

  factory ContainsSignable.ioTransaction(IoTransaction iotx) {
    /// Strips the proofs from a SpentTransactionOutput.
    /// This is needed because the proofs are not part of the transaction's signable bytes
    SpentTransactionOutput stripInput(SpentTransactionOutput stxo) {
      final stripped = stxo.deepCopy();

      final attestation = stxo.attestation;
      if (attestation.hasPredicate()) {
        return stripped..attestation.predicate.responses.clear();
      } else if (attestation.hasImage()) {
        return stripped..attestation.image.responses.clear();
      } else if (attestation.hasCommitment()) {
        return stripped..attestation.commitment.responses.clear();
      } else {
        return stripped;
      }
    }

    // TODO: seems to be some issue with stripping  here
    // final x = iotx.rebuild((p0) {
    //   p0.inputs.clear();
    //   p0.inputs.addAll(iotx.inputs.map(stripInput));
    // });

    // copies then freezes not to impact the original object
    final updatedIotx = iotx.rebuild((p0) {
      p0.inputs.clear();
      final inp = iotx.inputs.map(stripInput);
      p0.inputs.addAll(inp);
    });

    return ContainsSignable.immutable(updatedIotx.immutable);

    // final st = iotx.deepCopy()..freeze();
    // return ContainsSignable.immutable(
    //     ContainsImmutable.apply(st.rebuild((p0) => p0.inputs.update(iotx.inputs.map(stripInput).toList())))
    //         .immutableBytes);
  }
  final SignableBytes signableBytes;
}

extension IoTransactionContainsSignableExtensions on IoTransaction {
  SignableBytes get signable =>
      ContainsSignable.ioTransaction(this).signableBytes;
}

extension ImmutableBytesContainsSignableExtension on ImmutableBytes {
  SignableBytes get signable => ContainsSignable.immutable(this).signableBytes;
}

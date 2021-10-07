part of 'package:mubrambl/model.dart';

class BoxId<T> {
  final Digest hash;

  BoxId(this.hash);

  factory BoxId.applyByteArray(Uint8List bytes) {
    return BoxId(Digest.from(bytes, BLAKE2B_256_DIGEST_SIZE));
  }

  factory BoxId.apply(Box<T> box) {
    return BoxId.fromEvidence(box.evidence);
  }

  factory BoxId.fromEvidence(Evidence? evidence) {
    return BoxId(evidence?.evBytes ??
        Digest(BLAKE2B_256_DIGEST_SIZE, Uint8List(BLAKE2B_256_DIGEST_SIZE)));
  }

  factory BoxId.fromJson(String json) {
    return BoxId.applyByteArray(Base58Data.validated(json).value);
  }

  String toJson() => toString();

  @override
  int get hashCode => hash.hashCode;

  @override
  bool operator ==(Object other) => other is BoxId && other.hash == hash;

  @override
  String toString() => hash.bytes.encodeAsBase58().show;
}

class BoxIdConverter implements JsonConverter<BoxId, String> {
  const BoxIdConverter();

  @override
  BoxId fromJson(String json) {
    return BoxId.fromJson(json);
  }

  @override
  String toJson(BoxId object) {
    return object.toString();
  }
}

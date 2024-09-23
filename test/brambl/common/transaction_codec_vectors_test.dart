import 'dart:typed_data';

import 'package:brambldart/brambldart.dart';
import 'package:test/test.dart';
import 'package:topl_common/proto/brambl/models/transaction/io_transaction.pb.dart';

void main() {
  group('TransactionCodecVectorsSpec', () {
    for (int i = 0; i < vectors.length; i++) {
      test("Vector $i", () {
        final vector = vectors[i];
        final txBytes = Encoding().decodeFromHex(vector.txHex).getOrThrow();
        final tx = IoTransaction.fromBuffer(txBytes)..freeze();
        final signable = ContainsSignable.ioTransaction(tx).signableBytes;
        final signableHex =
            Encoding().encodeToHex(Uint8List.fromList(signable.value));
        expect(signableHex, equals(vector.txSignableHex));
        expect(
            Encoding().encodeToBase58(Uint8List.fromList(tx.computeId.value)),
            equals(vector.txId));
      });
    }
  });
}

const vectors = [
  TestVector(
    txHex: "1a060a040a002200",
    txSignableHex: "0000",
    txId: "BhHbw2zXrJGgRW9YpKQV4c6sXfSwChXeYrRjW1aCQqRF",
  ),
  TestVector(
    txHex:
        "0a360a2422220a207b4ffd7c46c3884c6095e58a2eb4b28b610d6c3fd5a3297831f828a443d466a012040a020a001a080a060a040a0201f412340a28080510321a220a207b40522d25601601b7c859f735195500cc906183ae108dbc6e8a33b672bae97c12080a060a040a0201f41a060a040a002200",
    txSignableHex:
        "00000000696f5f7472616e73616374696f6e5f33327b4ffd7c46c3884c6095e58a2eb4b28b610d6c3fd5a3297831f828a443d466a00001f4000532626f785f6c6f636b5f33327b40522d25601601b7c859f735195500cc906183ae108dbc6e8a33b672bae97c01f40000",
    txId: "DeXDSTN9JCDb6RAvL3iGaX68fFtEm4gHFYtYMT6BEWwN",
  ),
  TestVector(
    txHex:
        "0a3d0a2b0808104318d90222220a2082d4b6b33397ec74b6394284db2f2be79a6a950c3f0863347a79d2e2b92830d912040a020a001a0812060a040a0201f412340a28080510321a220a20897af2e0eb81f85365ff98f6578516973d96b0109fbc63c4ed8c7ecf1d6e751412080a060a040a0201f41a3c0a3a0a1408b11210ffffffffffffffff7f18fba1caf9a13222220a209d252954ade1c5909d397d97db968db897c8e663d94594ff4d7567fde9e6efc0",
    txSignableHex:
        "0008430159696f5f7472616e73616374696f6e5f333282d4b6b33397ec74b6394284db2f2be79a6a950c3f0863347a79d2e2b92830d90001f4ff000532626f785f6c6f636b5f3332897af2e0eb81f85365ff98f6578516973d96b0109fbc63c4ed8c7ecf1d6e751401f409317fffffffffffffff9d252954ade1c5909d397d97db968db897c8e663d94594ff4d7567fde9e6efc0",
    txId: "FvhubX87rvQvcMiUAVtiowyLaNGh2atx8P8cAeFWj5h7",
  )
];

class TestVector {
  const TestVector(
      {required this.txHex, required this.txSignableHex, required this.txId});

  final String txHex;
  final String txSignableHex;
  final String txId;
}

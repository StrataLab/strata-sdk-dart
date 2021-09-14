import 'package:mubrambl/src/utils/constants.dart';
import 'modifier_id.dart';

typedef M = NodeViewModifier;

///
/// It is supposed that all the modifiers (offchain transactions, blocks, blockheaders etc)
/// have identifiers of the some length fixed with the ModifierIdSize constant
///
class NodeViewModifier {
  final ModifierTypeId modifierTypeId;
  final ModifierId id;
  final int modifierIdSize = MODIFIER_ID_SIZE;

  NodeViewModifier(this.modifierTypeId, this.id);

  @override
  String toString() => '[($modifierTypeId),($id)';
}

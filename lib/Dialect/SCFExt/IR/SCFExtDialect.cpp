#include "lib/Dialect/SCFExt/IR/SCFExtDialect.h"

#include <cassert>

#include "mlir/include/mlir/IR/BuiltinTypes.h"        // from @llvm-project
#include "mlir/include/mlir/IR/TypeUtilities.h"       // from @llvm-project
#include "mlir/include/mlir/Support/LLVM.h"           // from @llvm-project
#include "mlir/include/mlir/Support/LogicalResult.h"  // from @llvm-project

// NOLINTBEGIN(misc-include-cleaner): Required to define SCFExtDialect and
// SCFExtOps
#include "lib/Dialect/SCFExt/IR/SCFExtOps.h"
#include "llvm/include/llvm/ADT/MapVector.h"              // from @llvm-project
#include "llvm/include/llvm/ADT/SmallPtrSet.h"            // from @llvm-project
#include "llvm/include/llvm/ADT/TypeSwitch.h"             // from @llvm-project
#include "mlir/include/mlir/Dialect/Arith/IR/Arith.h"     // from @llvm-project
#include "mlir/include/mlir/Dialect/Arith/Utils/Utils.h"  // from @llvm-project
#include "mlir/include/mlir/Dialect/Bufferization/IR/BufferDeallocationOpInterface.h"  // from @llvm-project
#include "mlir/include/mlir/Dialect/Bufferization/IR/BufferizableOpInterface.h"  // from @llvm-project
#include "mlir/include/mlir/Dialect/ControlFlow/IR/ControlFlowOps.h"  // from @llvm-project
#include "mlir/include/mlir/Dialect/MemRef/IR/MemRef.h"  // from @llvm-project
#include "mlir/include/mlir/Dialect/SCF/IR/DeviceMappingInterface.h"  // from @llvm-project
#include "mlir/include/mlir/Dialect/Tensor/IR/Tensor.h"  // from @llvm-project
#include "mlir/include/mlir/IR/BuiltinAttributes.h"      // from @llvm-project
#include "mlir/include/mlir/IR/IRMapping.h"              // from @llvm-project
#include "mlir/include/mlir/IR/Matchers.h"               // from @llvm-project
#include "mlir/include/mlir/IR/PatternMatch.h"           // from @llvm-project
#include "mlir/include/mlir/Interfaces/FunctionInterfaces.h"  // from @llvm-project
#include "mlir/include/mlir/Interfaces/ValueBoundsOpInterface.h"  // from @llvm-project
#include "mlir/include/mlir/Transforms/InliningUtils.h"  // from @llvm-project

// NOLINTEND(misc-include-cleaner)

// Generated definitions
#include "lib/Dialect/SCFExt/IR/SCFExtDialect.cpp.inc"

#define GET_OP_CLASSES
#include "lib/Dialect/SCFExt/IR/SCFExtOps.cpp.inc"

namespace mlir {
namespace heir {
namespace scf_ext {

void SCFExtDialect::initialize() {
  addOperations<
#define GET_OP_LIST
#include "lib/Dialect/SCFExt/IR/SCFExtOps.cpp.inc"
      >();
  addInterfaces<SCFInlinerInterface>();
  declarePromisedInterfaces<bufferization::BufferizableOpInterface, SCFExtForOp,
                            SCFExtIfOp, SCFExtYieldOp>();
  declarePromisedInterface<ValueBoundsOpInterface, SCFExtForOp>();
}

// SCFExtForOp
void SCFExtForOp::build(OpBuilder &builder, OperationState &result, Value lb,
                        Value ub, Value step, ValueRange iterArgs,
                        BodyBuilderFn bodyBuilder) {
  OpBuilder::InsertionGuard guard(builder);

  result.addOperands({lb, ub, step});
  result.addOperands(iterArgs);
  for (Value v : iterArgs) result.addTypes(v.getType());
  Type t = lb.getType();
  Region *bodyRegion = result.addRegion();
  Block *bodyBlock = builder.createBlock(bodyRegion);
  bodyBlock->addArgument(t, result.location);
  for (Value v : iterArgs) bodyBlock->addArgument(v.getType(), v.getLoc());

  // Create the default terminator if the builder is not provided and if the
  // iteration arguments are not provided. Otherwise, leave this to the caller
  // because we don't know which values to return from the loop.
  if (iterArgs.empty() && !bodyBuilder) {
    SCFExtForOp::ensureTerminator(*bodyRegion, builder, result.location);
  } else if (bodyBuilder) {
    OpBuilder::InsertionGuard guard(builder);
    builder.setInsertionPointToStart(bodyBlock);
    bodyBuilder(builder, result.location, bodyBlock->getArgument(0),
                bodyBlock->getArguments().drop_front());
  }
}

LogicalResult SCFExtForOp::verify() {
  // Check that the number of init args and op results is the same.
  if (getInitArgs().size() != getNumResults())
    return emitOpError(
        "mismatch in number of loop-carried values and defined values");

  return success();
}

LogicalResult SCFExtForOp::verifyRegions() {
  // Check that the body defines as single block argument for the induction
  // variable.
  if (getInductionVar().getType() != getLowerBound().getType())
    return emitOpError(
        "expected induction variable to be same type as bounds and step");

  if (getNumRegionIterArgs() != getNumResults())
    return emitOpError(
        "mismatch in number of basic block args and defined values");

  auto initArgs = getInitArgs();
  auto iterArgs = getRegionIterArgs();
  auto opResults = getResults();
  unsigned i = 0;
  for (auto e : llvm::zip(initArgs, iterArgs, opResults)) {
    if (std::get<0>(e).getType() != std::get<2>(e).getType())
      return emitOpError() << "types mismatch between " << i
                           << "th iter operand and defined value";
    if (std::get<1>(e).getType() != std::get<2>(e).getType())
      return emitOpError() << "types mismatch between " << i
                           << "th iter region arg and defined value";

    ++i;
  }
  return success();
}

std::optional<SmallVector<Value>> SCFExtForOp::getLoopInductionVars() {
  return SmallVector<Value>{getInductionVar()};
}

std::optional<SmallVector<OpFoldResult>> SCFExtForOp::getLoopLowerBounds() {
  return SmallVector<OpFoldResult>{OpFoldResult(getLowerBound())};
}

std::optional<SmallVector<OpFoldResult>> SCFExtForOp::getLoopSteps() {
  return SmallVector<OpFoldResult>{OpFoldResult(getStep())};
}

std::optional<SmallVector<OpFoldResult>> SCFExtForOp::getLoopUpperBounds() {
  return SmallVector<OpFoldResult>{OpFoldResult(getUpperBound())};
}

std::optional<ResultRange> SCFExtForOp::getLoopResults() {
  return getResults();
}

/// Promotes the loop body of a SCFExtForOp to its containing block if the
/// SCFExtForOp it can be determined that the loop has a single iteration.
LogicalResult SCFExtForOp::promoteIfSingleIteration(RewriterBase &rewriter) {
  std::optional<int64_t> tripCount =
      constantTripCount(getLowerBound(), getUpperBound(), getStep());
  if (!tripCount.has_value() || tripCount != 1) return failure();

  // Replace all results with the yielded values.
  auto yieldOp = cast<scf::YieldOp>(getBody()->getTerminator());
  rewriter.replaceAllUsesWith(getResults(), getYieldedValues());

  // Replace block arguments with lower bound (replacement for IV) and
  // iter_args.
  SmallVector<Value> bbArgReplacements;
  bbArgReplacements.push_back(getLowerBound());
  llvm::append_range(bbArgReplacements, getInitArgs());

  // Move the loop body operations to the loop's containing block.
  rewriter.inlineBlockBefore(getBody(), getOperation()->getBlock(),
                             getOperation()->getIterator(), bbArgReplacements);

  // Erase the old terminator and the loop.
  rewriter.eraseOp(yieldOp);
  rewriter.eraseOp(*this);

  return success();
}

/// Prints the initialization list in the form of
///   <prefix>(%inner = %outer, %inner2 = %outer2, <...>)
/// where 'inner' values are assumed to be region arguments and 'outer' values
/// are regular SSA values.
static void printInitializationList(OpAsmPrinter &p,
                                    Block::BlockArgListType blocksArgs,
                                    ValueRange initializers,
                                    StringRef prefix = "") {
  assert(blocksArgs.size() == initializers.size() &&
         "expected same length of arguments and initializers");
  if (initializers.empty()) return;

  p << prefix << '(';
  llvm::interleaveComma(llvm::zip(blocksArgs, initializers), p, [&](auto it) {
    p << std::get<0>(it) << " = " << std::get<1>(it);
  });
  p << ")";
}

void SCFExtForOp::print(OpAsmPrinter &p) {
  p << " " << getInductionVar() << " = " << getLowerBound() << " to "
    << getUpperBound() << " step " << getStep();

  printInitializationList(p, getRegionIterArgs(), getInitArgs(), " iter_args");
  if (!getInitArgs().empty()) p << " -> (" << getInitArgs().getTypes() << ')';
  p << ' ';
  if (Type t = getInductionVar().getType(); !t.isIndex())
    p << " : " << t << ' ';
  p.printRegion(getRegion(),
                /*printEntryBlockArgs=*/false,
                /*printBlockTerminators=*/!getInitArgs().empty());
  p.printOptionalAttrDict((*this)->getAttrs());
}

ParseResult SCFExtForOp::parse(OpAsmParser &parser, OperationState &result) {
  auto &builder = parser.getBuilder();
  Type type;

  OpAsmParser::Argument inductionVariable;
  OpAsmParser::UnresolvedOperand lb, ub, step;

  // Parse the induction variable followed by '='.
  if (parser.parseOperand(inductionVariable.ssaName) || parser.parseEqual() ||
      // Parse loop bounds.
      parser.parseOperand(lb) || parser.parseKeyword("to") ||
      parser.parseOperand(ub) || parser.parseKeyword("step") ||
      parser.parseOperand(step))
    return failure();

  // Parse the optional initial iteration arguments.
  SmallVector<OpAsmParser::Argument, 4> regionArgs;
  SmallVector<OpAsmParser::UnresolvedOperand, 4> operands;
  regionArgs.push_back(inductionVariable);

  bool hasIterArgs = succeeded(parser.parseOptionalKeyword("iter_args"));
  if (hasIterArgs) {
    // Parse assignment list and results type list.
    if (parser.parseAssignmentList(regionArgs, operands) ||
        parser.parseArrowTypeList(result.types))
      return failure();
  }

  if (regionArgs.size() != result.types.size() + 1)
    return parser.emitError(
        parser.getNameLoc(),
        "mismatch in number of loop-carried values and defined values");

  // Parse optional type, else assume Index.
  if (parser.parseOptionalColon())
    type = builder.getIndexType();
  else if (parser.parseType(type))
    return failure();

  // Resolve input operands.
  regionArgs.front().type = type;
  if (parser.resolveOperand(lb, type, result.operands) ||
      parser.resolveOperand(ub, type, result.operands) ||
      parser.resolveOperand(step, type, result.operands))
    return failure();
  if (hasIterArgs) {
    for (auto argOperandType :
         llvm::zip(llvm::drop_begin(regionArgs), operands, result.types)) {
      Type type = std::get<2>(argOperandType);
      std::get<0>(argOperandType).type = type;
      if (parser.resolveOperand(std::get<1>(argOperandType), type,
                                result.operands))
        return failure();
    }
  }

  // Parse the body region.
  Region *body = result.addRegion();
  if (parser.parseRegion(*body, regionArgs)) return failure();

  SCFExtForOp::ensureTerminator(*body, builder, result.location);

  // Parse the optional attribute list.
  if (parser.parseOptionalAttrDict(result.attributes)) return failure();

  return success();
}

SmallVector<Region *> SCFExtForOp::getLoopRegions() { return {&getRegion()}; }

Block::BlockArgListType SCFExtForOp::getRegionIterArgs() {
  return getBody()->getArguments().drop_front(getNumInductionVars());
}

MutableArrayRef<OpOperand> SCFExtForOp::getInitsMutable() {
  return getInitArgsMutable();
}

FailureOr<LoopLikeOpInterface> SCFExtForOp::replaceWithAdditionalYields(
    RewriterBase &rewriter, ValueRange newInitOperands,
    bool replaceInitOperandUsesInLoop,
    const NewYieldValuesFn &newYieldValuesFn) {
  // Create a new loop before the existing one, with the extra operands.
  OpBuilder::InsertionGuard g(rewriter);
  rewriter.setInsertionPoint(getOperation());
  auto inits = llvm::to_vector(getInitArgs());
  inits.append(newInitOperands.begin(), newInitOperands.end());
  scf::SCFExtForOp newLoop = rewriter.create<scf::SCFExtForOp>(
      getLoc(), getLowerBound(), getUpperBound(), getStep(), inits,
      [](OpBuilder &, Location, Value, ValueRange) {});
  newLoop->setAttrs(getPrunedAttributeList(getOperation(), {}));

  // Generate the new yield values and append them to the scf.yield operation.
  auto yieldOp = cast<scf::YieldOp>(getBody()->getTerminator());
  ArrayRef<BlockArgument> newIterArgs =
      newLoop.getBody()->getArguments().take_back(newInitOperands.size());
  {
    OpBuilder::InsertionGuard g(rewriter);
    rewriter.setInsertionPoint(yieldOp);
    SmallVector<Value> newYieldedValues =
        newYieldValuesFn(rewriter, getLoc(), newIterArgs);
    assert(newInitOperands.size() == newYieldedValues.size() &&
           "expected as many new yield values as new iter operands");
    rewriter.modifyOpInPlace(yieldOp, [&]() {
      yieldOp.getResultsMutable().append(newYieldedValues);
    });
  }

  // Move the loop body to the new op.
  rewriter.mergeBlocks(getBody(), newLoop.getBody(),
                       newLoop.getBody()->getArguments().take_front(
                           getBody()->getNumArguments()));

  if (replaceInitOperandUsesInLoop) {
    // Replace all uses of `newInitOperands` with the corresponding basic block
    // arguments.
    for (auto it : llvm::zip(newInitOperands, newIterArgs)) {
      rewriter.replaceUsesWithIf(std::get<0>(it), std::get<1>(it),
                                 [&](OpOperand &use) {
                                   Operation *user = use.getOwner();
                                   return newLoop->isProperAncestor(user);
                                 });
    }
  }

  // Replace the old loop.
  rewriter.replaceOp(getOperation(),
                     newLoop->getResults().take_front(getNumResults()));
  return cast<LoopLikeOpInterface>(newLoop.getOperation());
}

SCFExtForOp mlir::scf::getForInductionVarOwner(Value val) {
  auto ivArg = llvm::dyn_cast<BlockArgument>(val);
  if (!ivArg) return SCFExtForOp();
  assert(ivArg.getOwner() && "unlinked block argument");
  auto *containingOp = ivArg.getOwner()->getParentOp();
  return dyn_cast_or_null<SCFExtForOp>(containingOp);
}

OperandRange SCFExtForOp::getEntrySuccessorOperands(RegionBranchPoint point) {
  return getInitArgs();
}

void SCFExtForOp::getSuccessorRegions(
    RegionBranchPoint point, SmallVectorImpl<RegionSuccessor> &regions) {
  // Both the operation itself and the region may be branching into the body or
  // back into the operation itself. It is possible for loop not to enter the
  // body.
  regions.push_back(RegionSuccessor(&getRegion(), getRegionIterArgs()));
  regions.push_back(RegionSuccessor(getResults()));
}

}  // namespace scf_ext
}  // namespace heir
}  // namespace mlir

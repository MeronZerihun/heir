#include "lib/Transforms/IntegerRangeTest/IntegerRangeTest.h"

#include <utility>

#include "llvm/include/llvm/Support/Debug.h"  // from @llvm-project
#include "mlir/include/mlir/Analysis/DataFlow/DeadCodeAnalysis.h"  // from @llvm-project
#include "mlir/include/mlir/Analysis/DataFlow/IntegerRangeAnalysis.h"  // from @llvm-project
#include "mlir/include/mlir/Analysis/DataFlowFramework.h"  // from @llvm-project
#include "mlir/include/mlir/Dialect/Func/IR/FuncOps.h"     // from @llvm-project
#include "mlir/include/mlir/Dialect/SCF/IR/SCF.h"          // from @llvm-project
#include "mlir/include/mlir/IR/Diagnostics.h"              // from @llvm-project
#include "mlir/include/mlir/IR/MLIRContext.h"              // from @llvm-project
#include "mlir/include/mlir/IR/PatternMatch.h"             // from @llvm-project
#include "mlir/include/mlir/IR/Visitors.h"                 // from @llvm-project
#include "mlir/include/mlir/Support/LLVM.h"                // from @llvm-project
#include "mlir/include/mlir/Support/LogicalResult.h"       // from @llvm-project

#define DEBUG_TYPE "integer-range-test"

namespace mlir {
namespace heir {

#define GEN_PASS_DEF_INTEGERRANGETEST
#include "lib/Transforms/IntegerRangeTest/IntegerRangeTest.h.inc"

struct IntegerRangeTest : impl::IntegerRangeTestBase<IntegerRangeTest> {
  using IntegerRangeTestBase::IntegerRangeTestBase;

  void runOnOperation() override {
    MLIRContext *context = &getContext();

    Operation *module = getOperation();

    RewritePatternSet patterns(context);

    DataFlowSolver solver;
    solver.load<dataflow::DeadCodeAnalysis>();
    solver.load<dataflow::IntegerRangeAnalysis>();

    if (failed(solver.initializeAndRun(module))) signalPassFailure();

    LLVM_DEBUG({
      // Add an attribute to the operations to show determined secretness
      OpBuilder builder(context);
      module->walk([&](Operation *op) {
        // If op doesn't return results, advance to the next op
        if (!op->getNumResults()) {
          return WalkResult::advance();
        }

        const dataflow::IntegerValueRangeLattice *opRange =
            solver.lookupState<dataflow::IntegerValueRangeLattice>(
                op->getResult(0));
        if (!opRange || opRange->getValue().isUninitialized()) {
          op->setAttr("integer-range",
                      builder.getStringAttr("null or unknown"));
          return WalkResult::interrupt();
        }
        ConstantIntRanges range = opRange->getValue().getValue();
        op->setAttr(
            "integer-range",
            builder.getStringAttr(
                "[" + std::to_string(range.smin().getZExtValue()) + ", " +
                std::to_string(range.smax().getZExtValue()) + "]"));

        return WalkResult::advance();
      });
    });
  }
};

}  // namespace heir
}  // namespace mlir

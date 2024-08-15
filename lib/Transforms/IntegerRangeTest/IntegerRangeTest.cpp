#include "lib/Transforms/IntegerRangeTest/IntegerRangeTest.h"

#include <utility>

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

    auto result = module->walk([&](Operation *op) {
      llvm::errs() << "$ Testing range of: " << *op << "\n";

      // If op doesn't return results, advance to the next op
      if (!op->getNumResults()) {
        return WalkResult::advance();
      }

      const dataflow::IntegerValueRangeLattice *opRange =
          solver.lookupState<dataflow::IntegerValueRangeLattice>(
              op->getResult(0));
      if (!opRange || opRange->getValue().isUninitialized()) {
        op->emitOpError()
            << "Found op without a set integer range; did the analysis fail?";
        return WalkResult::interrupt();
      }

      ConstantIntRanges range = opRange->getValue().getValue();
      op->emitRemark() << "Range: [" << range.smin().getZExtValue() << ", "
                       << range.smax().getZExtValue() << "]";

      return WalkResult::advance();
    });

    if (result.wasInterrupted()) signalPassFailure();
  }
};

}  // namespace heir
}  // namespace mlir

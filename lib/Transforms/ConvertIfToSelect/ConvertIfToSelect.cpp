#include "lib/Transforms/ConvertIfToSelect/ConvertIfToSelect.h"

#include "lib/Analysis/SecretnessAnalysis/SecretnessAnalysis.h"
#include "mlir/include/mlir/Analysis/DataFlow/ConstantPropagationAnalysis.h"  // from @llvm-project
#include "mlir/include/mlir/Analysis/DataFlow/DeadCodeAnalysis.h"  // from @llvm-project
#include "mlir/include/mlir/Analysis/DataFlow/SparseAnalysis.h"  // from @llvm-project
#include "mlir/include/mlir/Dialect/SCF/IR/SCF.h"  // from @llvm-project
#include "mlir/include/mlir/IR/Operation.h"        // from @llvm-project
#include "mlir/include/mlir/IR/PatternMatch.h"     // from @llvm-project
#include "mlir/include/mlir/Interfaces/SideEffectInterfaces.h"  // from @llvm-project
#include "mlir/include/mlir/Transforms/GreedyPatternRewriteDriver.h"  // from @llvm-project
#include "mlir/include/mlir/Transforms/Passes.h"  // from @llvm-project

namespace mlir {
namespace heir {

#define GEN_PASS_DEF_CONVERTIFTOSELECT
#include "lib/Transforms/ConvertIfToSelect/ConvertIfToSelect.h.inc"

struct IfToSelectConversion : OpRewritePattern<scf::IfOp> {
  using OpRewritePattern<scf::IfOp>::OpRewritePattern;

  LogicalResult matchAndRewrite(scf::IfOp ifOp,
                                PatternRewriter &rewriter) const override {
    // Hoist instructions in the 'then' and 'else' regions
    auto thenOps = ifOp.getThenRegion().getOps();
    auto elseOps = ifOp.getElseRegion().getOps();

    rewriter.setInsertionPointToStart(ifOp.thenBlock());
    for (auto &operation : llvm::make_early_inc_range(
             llvm::concat<Operation>(thenOps, elseOps))) {
      if (!isPure(&operation)) {
        ifOp->emitError()
            << "Can't convert scf.if to arith.select operation. If-operation "
               "contains code that can't be safely hoisted on line "
            << operation.getLoc();
        return failure();
      }
      if (!llvm::isa<scf::YieldOp>(operation)) {
        rewriter.moveOpBefore(&operation, ifOp);
      }
    }

    // Translate YieldOp into SelectOp
    auto cond = ifOp.getCondition();
    auto thenYieldArgs = ifOp.thenYield().getOperands();
    auto elseYieldArgs = ifOp.elseYield().getOperands();

    SmallVector<Value> newIfResults(ifOp->getNumResults());
    if (ifOp->getNumResults() > 0) {
      rewriter.setInsertionPoint(ifOp);

      for (const auto &it :
           llvm::enumerate(llvm::zip(thenYieldArgs, elseYieldArgs))) {
        Value trueVal = std::get<0>(it.value());
        Value falseVal = std::get<1>(it.value());
        newIfResults[it.index()] = rewriter.create<arith::SelectOp>(
            ifOp.getLoc(), cond, trueVal, falseVal);
      }
      rewriter.replaceOp(ifOp, newIfResults);
    }

    return success();
  }
};

struct ConvertIfToSelect : impl::ConvertIfToSelectBase<ConvertIfToSelect> {
  using ConvertIfToSelectBase::ConvertIfToSelectBase;

void runOnOperation() override {
    llvm::errs() << "RunOnOperation\n";
    MLIRContext *context = &getContext();

    RewritePatternSet patterns(context);

    DataFlowSolver solver;
    solver.load<dataflow::DeadCodeAnalysis>();
    solver.load<dataflow::SparseConstantPropagation>();
    solver.load<SecretnessAnalysis>();

    auto result = solver.initializeAndRun(getOperation());

    if (failed(result)) {
      getOperation()->emitOpError() << "Failed to run the analysis.\n";
      signalPassFailure();
      return;
    }

    OpBuilder builder(context);
    llvm::errs() << "Start walking\n";

    getOperation()->walk([&](Operation *operation) {
      llvm::errs() << "Operation: " << operation->getName() << "\n";
      for (auto operand : operation->getOperands()) {
        Secretness lattice =
            (solver.lookupState<SecretnessLattice>(operand))->getValue();
        llvm::errs() << "\tOperand : " << operand << "; lattice: ";
        lattice.print(llvm::errs());
      }
      for (auto result : operation->getResults()) {
        Secretness lattice =
            (solver.lookupState<SecretnessLattice>(result))->getValue();
        llvm::errs() << "\tResult : " << result << "; lattice: ";
        lattice.print(llvm::errs());
      }
    });

    patterns.add<IfToSelectConversion>(context);
    (void)applyPatternsAndFoldGreedily(getOperation(), std::move(patterns));
  }
};

}  // namespace heir
}  // namespace mlir

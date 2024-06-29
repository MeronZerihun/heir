#include "lib/Analysis/SecretnessAnalysis/SecretnessAnalysis.h"

#include <llvm/Support/raw_ostream.h>

#include "lib/Dialect/Secret/IR/SecretOps.h"
#include "lib/Dialect/Secret/IR/SecretTypes.h"
#include "llvm/include/llvm/ADT/TypeSwitch.h"      // from @llvm-project
#include "mlir/include/mlir/Dialect/SCF/IR/SCF.h"  // from @llvm-project
#include "mlir/include/mlir/IR/Operation.h"        // from @llvm-project
#include "mlir/include/mlir/IR/Value.h"            // from @llvm-project
#include "mlir/include/mlir/IR/Visitors.h"         // from @llvm-project
#include "mlir/include/mlir/Support/LLVM.h"        // from @llvm-project

namespace mlir {
namespace heir {

void SecretnessAnalysis::setToEntryState(SecretnessLattice *lattice) {
  llvm::errs() << "Entry State ";

  auto operand = lattice->getPoint();
  operand.dump();
  bool isSecret = isa<secret::SecretType>(operand.getType());

  Operation *operation = nullptr;
  if (auto blockArg = dyn_cast<BlockArgument>(operand)) {
    operation = blockArg.getOwner()->getParentOp();
  } else {
    operation = operand.getDefiningOp();
  }

  if (auto genericOp = dyn_cast<secret::GenericOp>(*operation)) {
    if (OpOperand *genericOperand =
            genericOp.getOpOperandForBlockArgument(operand)) {
      isSecret = isa<secret::SecretType>(genericOperand->get().getType());
    }
  }
  auto *secretness = new Secretness();
  secretness->setSecretness(isSecret);
  propagateIfChanged(lattice, lattice->join(*secretness));
  llvm::errs() << lattice->getValue();

  llvm::errs() << "-- Done Entry State --\n";
}

void SecretnessAnalysis::visitOperation(
    Operation *operation, ArrayRef<const SecretnessLattice *> operands,
    ArrayRef<SecretnessLattice *> results) {
  llvm::errs() << "Visiting operation: " << operation->getName() << "\n";

  for (const SecretnessLattice *operand : operands) {
    bool isSecret = false;
    for (SecretnessLattice *result : results) {
      auto *operandSecretness = &(operand->getValue());
      result->getPoint().dump();
      auto *secretness = new Secretness();
      if (operandSecretness->isInitialized() &&
          operandSecretness->getSecretness()) {
        isSecret = true;
        secretness->setSecretness(isSecret);
        propagateIfChanged(result, result->join(*secretness));
      } else {
        secretness->setSecretness(isSecret);
        propagateIfChanged(result, result->join(*secretness));
      }
      llvm::errs() << result->getValue();
    }
    if (isSecret) break;
  }
  llvm::errs() << "-- Done Visiting Operation --\n";
}

}  // namespace heir
}  // namespace mlir

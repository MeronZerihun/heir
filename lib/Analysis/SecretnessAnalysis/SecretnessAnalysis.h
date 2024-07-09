#ifndef LIB_ANALYSIS_SECRETNESSANALYSIS_SECRETNESSANALYSIS_H_
#define LIB_ANALYSIS_SECRETNESSANALYSIS_SECRETNESSANALYSIS_H_

#include <optional>

#include "mlir/include/mlir/Analysis/DataFlow/SparseAnalysis.h"  // from @llvm-project
#include "mlir/include/mlir/IR/Operation.h"  // from @llvm-project
#include "mlir/include/mlir/IR/Value.h"      // from @llvm-project

namespace mlir {
namespace heir {

class Secretness {
 public:
  Secretness() : secretness(std::nullopt) {}
  explicit Secretness(bool value) : secretness(value) {}
  ~Secretness() = default;

  const bool &getSecretness() const {
    assert(isInitialized());
    return *secretness;
  }
  void setSecretness(bool value) { secretness = value; }

  bool isInitialized() const { return secretness.has_value(); }

  bool operator==(const Secretness &rhs) const {
    return secretness == rhs.secretness;
  }

  static Secretness join(const Secretness &lhs, const Secretness &rhs) {
    if (!lhs.isInitialized()) return rhs;
    if (!rhs.isInitialized()) return lhs;

    return Secretness{lhs.getSecretness() || rhs.getSecretness()};
  }

  void print(raw_ostream &os) const { os << "Secretness: " << secretness; }

 private:
  std::optional<bool> secretness;
};

inline raw_ostream &operator<<(raw_ostream &os, const Secretness &value) {
  value.print(os);
  return os;
}
class SecretnessLattice : public dataflow::Lattice<Secretness> {
 public:
  using Lattice::Lattice;
};

class SecretnessAnalysis
    : public dataflow::SparseForwardDataFlowAnalysis<SecretnessLattice> {
 public:
  explicit SecretnessAnalysis(DataFlowSolver &solver)
      : SparseForwardDataFlowAnalysis(solver) {}
  ~SecretnessAnalysis() override = default;
  using SparseForwardDataFlowAnalysis::SparseForwardDataFlowAnalysis;

  void setToEntryState(SecretnessLattice *lattice) override;

  void visitOperation(Operation *operation,
                      ArrayRef<const SecretnessLattice *> operands,
                      ArrayRef<SecretnessLattice *> results) override;
};

}  // namespace heir
}  // namespace mlir

#endif  // LIB_ANALYSIS_SECRETNESSANALYSIS_SECRETNESSANALYSIS_H_

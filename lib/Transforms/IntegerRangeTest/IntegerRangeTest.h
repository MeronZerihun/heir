#ifndef LIB_TRANSFORMS_INTEGERRANGETEST_INTEGERRANGETEST_H_
#define LIB_TRANSFORMS_INTEGERRANGETEST_INTEGERRANGETEST_H_

#include "mlir/include/mlir/Pass/Pass.h"  // from @llvm-project

namespace mlir {
namespace heir {

#define GEN_PASS_DECL
#include "lib/Transforms/IntegerRangeTest/IntegerRangeTest.h.inc"

#define GEN_PASS_REGISTRATION
#include "lib/Transforms/IntegerRangeTest/IntegerRangeTest.h.inc"

}  // namespace heir
}  // namespace mlir

#endif  // LIB_TRANSFORMS_INTEGERRANGETEST_INTEGERRANGETEST_H_

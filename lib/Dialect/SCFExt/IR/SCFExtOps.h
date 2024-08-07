#ifndef LIB_DIALECT_SCFEXT_IR_SCFEXTOPS_H_
#define LIB_DIALECT_SCFEXT_IR_SCFEXTOPS_H_

// NOLINTBEGIN(misc-include-cleaner): Required to define SCFExtOps
#include "lib/Dialect/SCFExt/IR/SCFExtDialect.h"
#include "mlir/include/mlir/IR/BuiltinOps.h"  // from @llvm-project
#include "mlir/include/mlir/Interfaces/InferTypeOpInterface.h"  // from @llvm-project
// NOLINTEND(misc-include-cleaner)

#define GET_OP_CLASSES
#include "lib/Dialect/SCFExt/IR/SCFExtOps.h.inc"

#endif  // LIB_DIALECT_SCFEXT_IR_SCFEXTOPS_H_

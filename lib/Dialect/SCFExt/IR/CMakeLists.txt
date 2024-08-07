set(LLVM_TARGET_DEFINITIONS SCFExtDialect.td)
mlir_tablegen(SCFExtDialect.h.inc -gen-dialect-decls)
mlir_tablegen(SCFExtDialect.cpp.inc -gen-dialect-defs)
add_public_tablegen_target(MLIRSCFExtIncGen)

set(LLVM_TARGET_DEFINITIONS SCFExtOps.td)
mlir_tablegen(SCFExtOps.h.inc -gen-op-decls)
mlir_tablegen(SCFExtOps.cpp.inc -gen-op-defs)
add_public_tablegen_target(MLIRSCFExtOpsIncGen)

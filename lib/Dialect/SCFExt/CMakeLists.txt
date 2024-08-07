add_subdirectory(IR)
add_mlir_dialect_library(MLIRSCFExtDialect
        IR/SCFExtDialect.cpp

        ADDITIONAL_HEADER_DIRS
        ${CMAKE_CURRENT_SOURCE_DIR}/IR

        DEPENDS
        MLIRSCFExtIncGen
        MLIRSCFExtOpsIncGen

        LINK_LIBS PUBLIC
        LLVMSupport
        MLIRArithDialect
        MLIRIR
        MLIRInferTypeOpInterface
        MLIRSupport
)

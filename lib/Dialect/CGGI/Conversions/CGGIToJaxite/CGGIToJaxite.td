#ifndef LIB_DIALECT_CGGI_CONVERSIONS_CGGITOJAXITE_CGGITOJAXITE_TD_
#define LIB_DIALECT_CGGI_CONVERSIONS_CGGITOJAXITE_CGGITOJAXITE_TD_

include "mlir/Pass/PassBase.td"

def CGGIToJaxite : Pass<"cggi-to-jaxite"> {
  let summary = "Lower `cggi` to `jaxite` dialect.";
  let dependentDialects = [
    "mlir::arith::ArithDialect",
    "mlir::heir::jaxite::JaxiteDialect",
  ];
}

#endif  // LIB_DIALECT_CGGI_CONVERSIONS_CGGITOJAXITE_CGGITOJAXITE_TD_

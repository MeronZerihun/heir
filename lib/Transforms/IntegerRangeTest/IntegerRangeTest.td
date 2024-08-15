#ifndef LIB_TRANSFORMS_INTEGERRANGETEST_INTEGERRANGETEST_TD_
#define LIB_TRANSFORMS_INTEGERRANGETEST_INTEGERRANGETEST_TD_

include "mlir/Pass/PassBase.td"

def IntegerRangeTest : Pass<"integer-range-test"> {
  let summary = "Integer Range Test";
  let description = [{
  Uses upstream integer range analysis to test the range of values.
  }];

}

#endif  // LIB_TRANSFORMS_INTEGERRANGETEST_INTEGERRANGETEST_TD_

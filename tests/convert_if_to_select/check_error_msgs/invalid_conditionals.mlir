// TODO: Add RUN command and file check for checking diagnostic messages
// Helper function
func.func private @printer(%inp: tensor<16xi16>) -> ()

// CHECK-LABEL: @impure_operation
func.func @impure_operation(%inp: !secret.secret<tensor<16xi16>>, %cond: i1) -> !secret.secret<tensor<16xi16>> {
  %0 = secret.generic ins(%inp, %cond : !secret.secret<tensor<16xi16>>, i1) {
  ^bb0(%secret_inp: tensor<16xi16>, %copy_cond: i1):
    %1 = scf.if %copy_cond -> (tensor<16xi16>) {
      %2 = arith.addi %secret_inp, %secret_inp : tensor<16xi16>
      func.call @printer(%2) : (tensor<16xi16>) -> ()
      scf.yield %2 : tensor<16xi16>
    } else {
      scf.yield %secret_inp : tensor<16xi16>
    }
    secret.yield %1 : tensor<16xi16>
  } -> !secret.secret<tensor<16xi16>>
  return %0 : !secret.secret<tensor<16xi16>>
}
// Expected Output -> Error message: Can't apply If-transformation. If-operation contains side effects from printer() function call on line <>

// -----
// CHECK-LABEL: @non_speculative_code
func.func @non_speculative_code(%inp: !secret.secret<i16>, %divisor: !secret.secret<i16>) -> !secret.secret<i16> {
  %0 = secret.generic ins(%inp, %divisor : !secret.secret<i16>, !secret.secret<i16>) {
  ^bb0(%secret_inp: i16, %secret_divisor: i16):
    %0 = arith.constant 0 : i16
    %secret_cond = arith.cmpi eq, %0, %secret_divisor : i16
    %1 = scf.if %secret_cond -> (i16) {
      %2 = arith.divui %secret_inp, %secret_divisor : i16 // non-pure
      scf.yield %2 : i16
    } else {
      scf.yield %secret_inp : i16
    }
    secret.yield %1 : i16
  } -> !secret.secret<i16>
  return %0 : !secret.secret<i16>
}
// Expected Output -> Error Message: Can't apply If-transformation. If-operation contains non-speculatable code on line <>

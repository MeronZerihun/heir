// RUN: heir-opt  %s | FileCheck %s

// CHECK-LABEL: @secret_condition_with_non_secret_int
func.func @secret_condition_with_non_secret_int(%inp: i16, %cond: !secret.secret<i1>) -> !secret.secret<i16> {
  // CHECK-NEXT: %[[RESULT:.*]] = secret.generic ins(%[[INP:.*]], %[[COND:.*]] : [[T:.*]], !secret.secret<i1>) {
  // CHECK-NEXT:   ^[[bb0:.*]](%[[CPY_INP:.*]]: [[T]], %[[SCRT_COND:.*]]: i1):
  // CHECK-NEXT:     %[[ADD:.*]] = arith.addi %[[CPY_INP]], %[[CPY_INP]] : [[T]]
  // CHECK-NEXT:     %[[SEL:.*]] = arith.select %[[SCRT_COND]], %[[ADD]], %[[CPY_INP]] : [[T]]
  // CHECK-NEXT:     secret.yield %[[SEL]] : [[T]]
  // CHECK-NEXT:   } -> !secret.secret<[[T]]>
  // CHECK-NEXT: return %[[RESULT]] : !secret.secret<[[T]]>
  %0 = secret.generic ins(%inp, %cond : i16, !secret.secret<i1>) {
    ^bb0(%copy_inp: i16, %secret_cond: i1):
      %2 = arith.addi %copy_inp, %copy_inp : i16
      %1 = arith.select %secret_cond, %2, %copy_inp : i16
      secret.yield %1 : i16
    } -> !secret.secret<i16>
    return %0 : !secret.secret<i16>
}

// -----

// CHECK-LABEL: @secret_condition_with_secret_int
func.func @secret_condition_with_secret_int(%inp: !secret.secret<i16>, %cond: !secret.secret<i1>) -> !secret.secret<i16> {
  // CHECK-NEXT: %[[RESULT:.*]] = secret.generic ins(%[[INP:.*]], %[[COND:.*]] : !secret.secret<[[T:.*]]>, !secret.secret<i1>) {
  // CHECK-NEXT:   ^[[bb0:.*]](%[[SCRT_INP:.*]]: [[T]], %[[SCRT_COND:.*]]: i1):
  // CHECK-NEXT:     %[[ADD:.*]] = arith.addi %[[SCRT_INP]], %[[SCRT_INP]] : [[T]]
  // CHECK-NEXT:     %[[SEL:.*]] = arith.select %[[SCRT_COND]], %[[ADD]], %[[SCRT_INP]] : [[T]]
  // CHECK-NEXT:     secret.yield %[[SEL]] : [[T]]
  // CHECK-NEXT:  } -> !secret.secret<[[T]]>
  // CHECK-NEXT: return %[[RESULT]] : !secret.secret<[[T]]>
  %0 = secret.generic ins(%inp, %cond : !secret.secret<i16>, !secret.secret<i1>) {
    ^bb0(%secret_inp: i16, %secret_cond: i1):
      %2 = arith.addi %secret_inp, %secret_inp : i16
      %1 = arith.select %secret_cond, %2, %secret_inp : i16
      secret.yield %1 : i16
    } -> !secret.secret<i16>
    return %0 : !secret.secret<i16>
}

// -----

// CHECK-LABEL: @secret_condition_with_secret_int_and_multiple_yields
func.func @secret_condition_with_secret_int_and_multiple_yields(%inp: !secret.secret<i16>, %cond: !secret.secret<i1>) -> !secret.secret<i16> {
  // CHECK-NEXT: %[[RESULT:.*]] = secret.generic ins(%[[INP:.*]], %[[COND:.*]] : !secret.secret<[[T:.*]]>, !secret.secret<i1>) {
  // CHECK-NEXT:  ^[[bb0:.*]](%[[SCRT_INP:.*]]: [[T]], %[[SCRT_COND:.*]]: i1):
  // CHECK-NEXT:    %[[ADD1:.*]] = arith.addi %[[SCRT_INP]], %[[SCRT_INP]] : [[T]]
  // CHECK-NEXT:    %[[MUL:.*]] = arith.muli %[[SCRT_INP]], %[[ADD1]] : [[T]]
  // CHECK-NEXT:    %[[SEL1:.*]] = arith.select %[[SCRT_COND]], %[[ADD1]], %[[SCRT_INP]]  : [[T]]
  // CHECK-NEXT:    %[[SEL2:.*]] = arith.select %[[SCRT_COND]], %[[MUL]], %[[SCRT_INP]]  : [[T]]
  // CHECK-NEXT:    %[[ADD2:.*]] = arith.addi %[[SEL1]], %[[SEL2]] : [[T]]
  // CHECK-NEXT:    secret.yield %[[ADD2]] : [[T]]
  // CHECK-NEXT:  } -> !secret.secret<[[T]]>
  // CHECK-NEXT: return %[[RESULT]] : !secret.secret<[[T]]>
  %0 = secret.generic ins(%inp, %cond : !secret.secret<i16>, !secret.secret<i1>) {
  ^bb0(%secret_inp: i16, %secret_cond: i1):
    %2 = arith.addi %secret_inp, %secret_inp : i16
    %4 = arith.muli %secret_inp, %2 : i16
    %1 = arith.select %secret_cond, %2, %secret_inp : i16
    %3 = arith.select %secret_cond, %4, %secret_inp : i16
    %5 = arith.addi %1, %3 : i16
    secret.yield %5 : i16
  } -> !secret.secret<i16>
  return %0 : !secret.secret<i16>
}

// -----

// CHECK-LABEL: @secret_condition_with_secret_tensor
func.func @secret_condition_with_secret_tensor(%inp: !secret.secret<tensor<16xi16>>, %cond: !secret.secret<i1>) -> !secret.secret<tensor<16xi16>> {
  // CHECK-NEXT: %[[RESULT:.*]] = secret.generic ins(%[[INP:.*]], %[[COND:.*]] : !secret.secret<tensor<[[T:.*]]>>, !secret.secret<i1>)
  // CHECK-NEXT:  ^[[bb0:.*]](%[[SCRT_INP:.*]]: tensor<[[T:.*]]>, %[[SCRT_COND:.*]]: i1):
  // CHECK-NEXT:    %[[ADD:.*]] = arith.addi %[[SCRT_INP]], %[[SCRT_INP]] : tensor<[[T]]>
  // CHECK-NEXT:    %[[MUL:.*]] = arith.muli %[[SCRT_INP]], %[[SCRT_INP]] : tensor<[[T]]>
  // CHECK-NEXT:    %[[SEL:.*]] = arith.select %[[SCRT_COND]], %[[ADD]], %[[MUL]] : tensor<[[T]]>
  // CHECK-NEXT:    secret.yield %[[SEL]] : tensor<[[T]]>
  // CHECK-NEXT:  } -> !secret.secret<tensor<[[T]]>>
  // CHECK-NEXT: return %[[RESULT]] : !secret.secret<tensor<[[T]]>>
  %0 = secret.generic ins(%inp, %cond : !secret.secret<tensor<16xi16>>, !secret.secret<i1>) {
    ^bb0(%secret_inp: tensor<16xi16>, %secret_cond: i1):
      %2 = arith.addi %secret_inp, %secret_inp : tensor<16xi16>
      %3 = arith.muli %secret_inp, %secret_inp : tensor<16xi16>
      %1 = arith.select %secret_cond, %2, %3 : tensor<16xi16>
      secret.yield %1 : tensor<16xi16>
    } -> !secret.secret<tensor<16xi16>>
    return %0 : !secret.secret<tensor<16xi16>>
}

// -----

// CHECK-LABEL: @non_secret_condition_with_secret_tensor
func.func @non_secret_condition_with_secret_tensor(%inp: !secret.secret<tensor<16xi16>>, %cond: i1) -> !secret.secret<tensor<16xi16>> {
  // CHECK-NEXT: %[[RESULT:.*]] = secret.generic ins(%[[INP:.*]], %[[COND:.*]] : !secret.secret<tensor<[[T:.*]]>>, i1) {
  // CHECK-NEXT:   ^[[bb0:.*]](%[[SCRT_INP:.*]]: tensor<[[T]]>, %[[CPY_COND:.*]]: i1):
  // CHECK-NEXT:      %[[IF:.*]] = scf.if %[[CPY_COND]] -> (tensor<[[T]]>) {
  // CHECK-NEXT:        %[[ADD:.*]] = arith.addi %[[SCRT_INP]], %[[SCRT_INP]] : tensor<[[T]]>
  // CHECK-NEXT:        scf.yield %[[ADD]] : tensor<[[T]]>
  // CHECK-NEXT:      } else {
  // CHECK-NEXT:        scf.yield %[[SCRT_INP]] : tensor<[[T]]>
  // CHECK-NEXT:      }
  // CHECK-NEXT:      secret.yield %[[IF]] : tensor<[[T]]>
  // CHECK-NEXT:   } -> !secret.secret<tensor<[[T]]>>
  // CHECK-NEXT: return %[[RESULT]] : !secret.secret<tensor<[[T]]>>
  %0 = secret.generic ins(%inp, %cond : !secret.secret<tensor<16xi16>>, i1) {
    ^bb0(%secret_inp: tensor<16xi16>, %copy_cond: i1):
      %1 = scf.if %copy_cond -> (tensor<16xi16>) {
        %2 = arith.addi %secret_inp, %secret_inp : tensor<16xi16>
        scf.yield %2 : tensor<16xi16>
      } else {
        scf.yield %secret_inp : tensor<16xi16>
      }
      secret.yield %1 : tensor<16xi16>
    } -> !secret.secret<tensor<16xi16>>
    return %0 : !secret.secret<tensor<16xi16>>
}

// -----

// CHECK-LABEL: @secret_condition_with_secret_vector
func.func @secret_condition_with_secret_vector(%inp: !secret.secret<vector<4xf32>>, %cond: !secret.secret<i1>) -> !secret.secret<vector<4xf32>> {
  // CHECK-NEXT: %[[RESULT:.*]] = secret.generic ins(%[[INP:.*]], %[[COND:.*]] : !secret.secret<vector<[[T:.*]]>>, !secret.secret<i1>) {
  // CHECK-NEXT:  ^[[bb0:.*]](%[[SCRT_INP:.*]]: vector<[[T]]>, %[[SCRT_COND:.*]]: i1):
  // CHECK-NEXT:   %[[ADD:.*]] = arith.addf %[[SCRT_INP]], %[[SCRT_INP]] : vector<[[T]]>
  // CHECK-NEXT:   %[[SEL:.*]] = arith.select %[[SCRT_COND]], %[[ADD]], %[[SCRT_INP]] : vector<[[T]]>
  // CHECK-NEXT:   secret.yield %[[SEL]] : vector<[[T]]>
  // CHECK-NEXT:  } -> !secret.secret<vector<[[T]]>>
  // CHECK-NEXT: return %[[RESULT]] : !secret.secret<vector<[[T]]>>
  %0 = secret.generic ins(%inp, %cond : !secret.secret<vector<4xf32>>, !secret.secret<i1>) {
  ^bb0(%secret_inp: vector<4xf32>, %secret_cond: i1):
    %2 = arith.addf %secret_inp, %secret_inp : vector<4xf32>
    %1 = arith.select %secret_cond, %2, %secret_inp : vector<4xf32>
    secret.yield %1 : vector<4xf32>
  } -> !secret.secret<vector<4xf32>>
  return %0 : !secret.secret<vector<4xf32>>
}

// -----

// CHECK-LABEL: @tainted_condition
func.func @tainted_condition(%inp: !secret.secret<i16>) -> !secret.secret<i16>{
  // CHECK-NEXT: %[[ZERO:.*]] = arith.constant 0 : [[T:.*]]
  // CHECK-NEXT: %[[RESULT:.*]] = secret.generic ins(%[[INP:.*]] : !secret.secret<[[T]]>) {
  // CHECK-NEXT:  ^[[bb0:.*]](%[[SCRT_INP:.*]]: [[T]]):
  // CHECK-NEXT:    %[[CMP:.*]] = arith.cmpi eq, %[[SCRT_INP]], %[[ZERO]]  : [[T]]
  // CHECK-NEXT:    %[[ADD:.*]] = arith.addi %[[SCRT_INP]], %[[SCRT_INP]] : [[T]]
  // CHECK-NEXT:    %[[SEL:.*]] = arith.select %[[CMP]], %[[ADD]], %[[SCRT_INP]] : [[T]]
  // CHECK-NEXT:    secret.yield %[[SEL]] : [[T]]
  // CHECK-NEXT:  } -> !secret.secret<[[T]]>
  // CHECK-NEXT: return %[[RESULT]] : !secret.secret<[[T]]>
  %0 = arith.constant 0 : i16
  %1 = secret.generic ins(%inp: !secret.secret<i16>) {
    ^bb0(%secret_inp: i16):
      %2 = arith.cmpi eq, %secret_inp, %0 : i16
      %4 = arith.addi %secret_inp, %secret_inp : i16
      %3 = arith.select %2, %4, %secret_inp : i16
      secret.yield %3 : i16
  } -> !secret.secret<i16>

  return %1 : !secret.secret<i16>
}

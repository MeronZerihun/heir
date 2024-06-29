func.func @conditionally_speculative_code(%inp: !secret.secret<i16>, %cond :!secret.secret<i1>) -> !secret.secret<i16> {
  %divisor = arith.constant 0 : i16
  %0 = secret.generic ins(%inp, %cond : !secret.secret<i16>, !secret.secret<i1>) {
  ^bb0(%secret_inp: i16, %secret_cond: i1):
    %1 = scf.if %secret_cond -> (i16) {
      // expected-error@below {{Cannot convert scf.if to arith.select, as it contains code that cannot be safely hoisted:}}
      %2 = arith.divui %secret_inp, %divisor : i16
      scf.yield %2 : i16
    } else {
      scf.yield %secret_inp : i16
    }
    secret.yield %1 : i16
  } -> !secret.secret<i16>
  return %0 : !secret.secret<i16>
}
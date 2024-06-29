module{
func.func @secret_condition_with_non_secret_int(%arg0: i16, %arg1: !secret.secret<i1>) -> !secret.secret<i16> {
    %0 = arith.addi %arg0, %arg0 : i16
    %1 = secret.generic ins(%arg0, %arg1 : i16, !secret.secret<i1>) {
    ^bb0(%arg2: i16, %arg3: i1):
      %2 = arith.muli %arg2, %arg2 : i16
      %3 = scf.if %arg3 -> (i16) {
        scf.yield %2 : i16
      } else {
        scf.yield %arg2 : i16
      }
      %4 = arith.addi %3, %0 : i16
      %5 = arith.muli %2, %4 : i16
      secret.yield %5 : i16
    } -> !secret.secret<i16>
    return %1 : !secret.secret<i16>
  }
}

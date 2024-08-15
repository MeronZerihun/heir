func.func @foo() -> (i8){
    %input = arith.constant 0 : i8
    %max = arith.constant 3 : index
    %i0 = arith.constant 0 : index
    %i1 = arith.constant 1 : index
    %i5 = arith.constant 5 : index
    %c10 = arith.constant 10 : i8
    %for = scf.for %i = %i0 to %i5 step %i1 iter_args(%arg0 = %input) -> (i8) {
        %cond = arith.cmpi sgt, %i, %max : index
        %c100 = arith.constant 100 : i8
        scf.break(%cond) %c100 : i8
        scf.yield %c10 : i8
    }
    %result = arith.addi %for, %c10 : i8
    return %result : i8
}

func.func @foo() -> i32{
    %five = arith.constant 5 : i32
    %max = arith.constant 7 : i32
    %i0 = arith.constant 0 : index
    %i1 = arith.constant 1 : index
    %i3 = arith.constant 3 : index
    %for = scf.for %i = %i0 to %i3 step %i1 iter_args(%arg0 = %five) -> (i32) {
        %c = index.casts %i : index to i32
        %temp = arith.addi %arg0, %c : i32
        %cond = arith.cmpi sgt, %temp, %max : i32
        scf.break(%cond) %five : i32
        scf.yield %temp : i32
    }
    // %result = 10
    %result = arith.addi %for, %five : i32
    return %result : i32
}

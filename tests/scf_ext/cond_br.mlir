func.func @foo() -> (i8){
    %c0 = arith.constant 0 : i8
    %c10 = arith.constant 10 : i8
    %c100 = arith.constant 100 : i8

    %max_idx = arith.constant 3 : i8

    // i > 3
    %cond = arith.cmpi sgt, %c0, %max_idx : i8
    cf.cond_br %cond, ^bb1(%c10 : i8), ^bb1(%c100 : i8)
    ^bb1(%arg: i8):
        %result = arith.addi %arg, %c10 : i8
        return %result : i8

}

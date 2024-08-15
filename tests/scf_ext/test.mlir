func.func @test_break(%input: tensor<16xi32>) -> i32 {
    %zero = arith.constant 0 : i32
    %i0 = arith.constant 0 : index
    %i16 = arith.constant 16 : index
    %step = arith.constant 1 : index

    %sum = scf.for %i = %i0 to %i16 step %step iter_args(%arg0 = %zero) -> (i32) {
      %extracted = tensor.extract %input[%i] : tensor<16xi32>

      %cond = arith.cmpi slt, %extracted, %zero : i32
      scf.break(%cond) %arg0 : i32

      %temp = arith.addi %arg0, %extracted : i32
      scf.yield %temp : i32
    }

    return %sum : i32
}

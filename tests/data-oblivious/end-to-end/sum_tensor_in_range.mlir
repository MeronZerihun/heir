func.func @sumTensorInRange(%input: tensor<16xi32>, %lower: index, %upper:index) -> i32{
    // add range check 
    %tempTensor = tensor.empty() : tensor<1xi32>
    %c_0 = arith.constant 0 : i32
    %i_0 = arith.constant 0 : index
    %step = arith.constant 1 : index
    %sumTensor = tensor.insert %c_0 into %tempTensor[%i_0] : tensor<1xi32>
    %sum = scf.for %i = %lower to %upper step %step iter_args(%arg = %sumTensor) -> (tensor<1xi32>) {
        %extracted = tensor.extract %arg[%i_0] : tensor<1xi32>
        %input_i = tensor.extract %input[%i] : tensor<16xi32>
        %temp = arith.addi %extracted, %input_i : i32
        %newSum = tensor.insert %temp into %arg[%i_0] : tensor<1xi32>
        scf.yield %newSum : tensor<1xi32>
    }

    %sum_i32 = tensor.extract %sum[%i_0] : tensor<1xi32>
    return %sum_i32 : i32
}
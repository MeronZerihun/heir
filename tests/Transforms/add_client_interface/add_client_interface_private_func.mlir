// RUN: heir-opt --add-client-interface %s | FileCheck %s

!ct_ty = !secret.secret<tensor<1024xi16>>

#alignment = #tensor_ext.alignment<in = [32], out = [1024]>
#layout = #tensor_ext.layout<map = (d0) -> (d0), alignment = #alignment>
#original_type = #tensor_ext.original_type<originalType = tensor<32xi16>, layout = #layout>

#scalar_alignment = #tensor_ext.alignment<in = [], out = [1024], insertedDims = [0]>
#scalar_layout = #tensor_ext.layout<map = (d0) -> (d0), alignment = #scalar_alignment>
#scalar_original_type = #tensor_ext.original_type<originalType = i16, layout = #scalar_layout>

module {
  func.func private @external_func(!ct_ty) -> !ct_ty

  func.func @simple_sum(
      %arg0: !ct_ty {tensor_ext.original_type = #original_type}
  ) -> (!ct_ty {tensor_ext.original_type = #scalar_original_type}) {
    %c16 = arith.constant 16 : index
    %c8 = arith.constant 8 : index
    %c4 = arith.constant 4 : index
    %c2 = arith.constant 2 : index
    %c1 = arith.constant 1 : index
    %0 = secret.generic(%arg0 : !ct_ty) {
    ^body(%pt_arg0: tensor<1024xi16>):
      %0 = tensor_ext.rotate %pt_arg0, %c16 : tensor<1024xi16>, index
      %1 = arith.addi %pt_arg0, %0 : tensor<1024xi16>
      %2 = tensor_ext.rotate %1, %c8 : tensor<1024xi16>, index
      %3 = arith.addi %1, %2 : tensor<1024xi16>
      %4 = tensor_ext.rotate %3, %c4 : tensor<1024xi16>, index
      %5 = arith.addi %3, %4 : tensor<1024xi16>
      %6 = tensor_ext.rotate %5, %c2 : tensor<1024xi16>, index
      %7 = arith.addi %5, %6 : tensor<1024xi16>
      %8 = tensor_ext.rotate %7, %c1 : tensor<1024xi16>, index
      %9 = arith.addi %7, %8 : tensor<1024xi16>
      secret.yield %9 : tensor<1024xi16>
    } -> !ct_ty
    return %0 : !ct_ty
  }

}

// CHECK-NOT: @external_func__encrypt
// CHECK-NOT: @external_func__decrypt

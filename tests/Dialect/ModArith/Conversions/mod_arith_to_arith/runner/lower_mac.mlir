// RUN: heir-opt %s --mod-arith-to-arith --heir-polynomial-to-llvm \
// RUN:   | mlir-runner -e test_lower_mac -entry-point-result=void \
// RUN:      --shared-libs="%mlir_lib_dir/libmlir_c_runner_utils%shlibext,%mlir_runner_utils" > %t
// RUN: FileCheck %s --check-prefix=CHECK_TEST_MAC < %t

func.func private @printMemrefI32(memref<*xi32>) attributes { llvm.emit_c_interface }

!Zp = !mod_arith.int<7681 : i26>
!Zpv = tensor<4x!Zp>

func.func @test_lower_mac() {
  // 67108862 is -2
  %x = arith.constant dense<[29498763, 42, 67108862, 7681]> : tensor<4xi26>
  // 36789492 is -30319372, 67108863 is -1
  %y = arith.constant dense<[36789492, 7234, 67108863, 7681]> : tensor<4xi26>
  %z = arith.constant dense<[0, 1, 2, 3]> : tensor<4xi26>
  %ex = mod_arith.encapsulate %x : tensor<4xi26> -> !Zpv
  %ey = mod_arith.encapsulate %y : tensor<4xi26> -> !Zpv
  %ez = mod_arith.encapsulate %z : tensor<4xi26> -> !Zpv
  %mx = mod_arith.reduce %ex : !Zpv
  %my = mod_arith.reduce %ey : !Zpv
  %mz = mod_arith.reduce %ez : !Zpv
  %m1 = mod_arith.mac %mx, %my, %mz : !Zpv
  %1 = mod_arith.extract %m1 : !Zpv -> tensor<4xi26>

  %2 = arith.extui %1 : tensor<4xi26> to tensor<4xi32>
  %3 = bufferization.to_buffer %2 : tensor<4xi32> to memref<4xi32>
  %U = memref.cast %3 : memref<4xi32> to memref<*xi32>
  func.call @printMemrefI32(%U) : (memref<*xi32>) -> ()
  return
}

// CHECK_TEST_MAC: [1600, 4270, 4, 3]

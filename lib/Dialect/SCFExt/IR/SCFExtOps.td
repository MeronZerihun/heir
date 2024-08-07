#ifndef LIB_DIALECT_SCFEXT_IR_SCFEXTOPS_TD_
#define LIB_DIALECT_SCFEXT_IR_SCFEXTOPS_TD_

include "lib/Dialect/SCFExt/IR/SCFExtDialect.td"
include "mlir/IR/BuiltinAttributes.td"
include "mlir/IR/CommonTypeConstraints.td"
include "mlir/IR/OpBase.td"
include "mlir/Interfaces/InferTypeOpInterface.td"
include "mlir/Interfaces/SideEffectInterfaces.td"

// SCFExt Dialect Ops
class SCFExt_Op<string mnemonic, list<Trait> traits = []> :
    Op<SCFExt_Dialect, mnemonic, traits>;


// SCFExt ForOp
def SCFExt_ForOp : SCF_ExtOp<"for",
      [AutomaticAllocationScope, DeclareOpInterfaceMethods<LoopLikeOpInterface,
       ["getInitsMutable", "getLoopResults", "getRegionIterArgs",
        "getLoopInductionVars", "getLoopLowerBounds", "getLoopSteps",
        "getLoopUpperBounds", "getYieldedValuesMutable",
        "promoteIfSingleIteration", "replaceWithAdditionalYields",
        "yieldTiledValuesAndReplace"]>,
       AllTypesMatch<["lowerBound", "upperBound", "step"]>,
       ConditionallySpeculatable,
       DeclareOpInterfaceMethods<RegionBranchOpInterface,
        ["getEntrySuccessorOperands"]>,
       SingleBlockImplicitTerminator<"scf_ext::YieldOp">,
       RecursiveMemoryEffects]> {
  let summary = "SCFExt for operation";
  let description = [{
    The `scf_ext.for` operation represents a loop taking 3 SSA value as operands that represent the lower bound, upper bound and step respectively. The operation defines an SSA value for its induction variable. It has one region capturing the loop body. The induction variable is represented as an argument of this region. This SSA value is a signless integer or index.
    The step is a value of same type but required to be positive. The lower and upper bounds specify a half-open range: the range includes the lower bound but does not include the upper bound.

    The body region must contain exactly one block that terminates with `scf_ext.yield`. Calling ForOp::build will create such a region and insert the terminator implicitly if none is defined, so will the parsing even in cases when it is absent from the custom format. For example:

    ```mlir
    // Index case.
    scf_ext.for %iv = %lb to %ub step %step {
      ... // body
    }
    ...
    // Integer case.
    scf_ext.for %iv_32 = %lb_32 to %ub_32 step %step_32 : i32 {
      ... // body
    }
    ```

    `scf_ext.for` can also operate on loop-carried variables and returns the final values after loop termination. The initial values of the variables are passed as additional SSA operands to the `scf_ext.for` following the 3 loop control SSA values mentioned above (lower bound, upper bound and step). The
    operation region has an argument for the induction variable, followed by one argument for each loop-carried variable, representing the value of the variable at the current iteration.

    The region must terminate with a `scf_ext.yield` that passes the current values of all loop-carried variables to the next iteration, or to the `scf_ext.for` result, if at the last iteration. The static type of a loop-carried variable may not change with iterations; its runtime type is allowed to change. Note, that when the loop-carried variables are present,
    calling ForOp::build will not insert the terminator implicitly. The caller must insert `scf_ext.yield` in that case.

    `scf_ext.for` results hold the final values after the last iteration. For example, to sum-reduce a memref:

    ```mlir
    func.func @reduce(%buffer: memref<1024xf32>, %lb: index,
                      %ub: index, %step: index) -> (f32) {
      // Initial sum set to 0.
      %sum_0 = arith.constant 0.0 : f32
      // iter_args binds initial values to the loop's region arguments.
      %sum = scf.for %iv = %lb to %ub step %step
          iter_args(%sum_iter = %sum_0) -> (f32) {
        %t = load %buffer[%iv] : memref<1024xf32>
        %sum_next = arith.addf %sum_iter, %t : f32
        // Yield current iteration sum to next iteration %sum_iter or to %sum
        // if final iteration.
        scf.yield %sum_next : f32
      }
      return %sum : f32
    }
    ```

    If the `scf_ext.for` defines any values, a yield must be explicitly present. The number and types of the `scf_ext.for` results must match the initial values in the `iter_args` binding and the yield operands.

    Another example with a nested `scf_ext.if` (see `scf_ext.if` for details) to perform conditional reduction:

    ```mlir
    func.func @conditional_reduce(%buffer: memref<1024xf32>, %lb: index,
                                  %ub: index, %step: index) -> (f32) {
      %sum_0 = arith.constant 0.0 : f32
      %c0 = arith.constant 0.0 : f32
      %sum = scf.for %iv = %lb to %ub step %step
          iter_args(%sum_iter = %sum_0) -> (f32) {
        %t = load %buffer[%iv] : memref<1024xf32>
        %cond = arith.cmpf "ugt", %t, %c0 : f32
        %sum_next = scf.if %cond -> (f32) {
          %new_sum = arith.addf %sum_iter, %t : f32
          scf.yield %new_sum : f32
        } else {
          scf.yield %sum_iter : f32
        }
        scf.yield %sum_next : f32
      }
      return %sum : f32
    }
    ```
  }];
  let arguments = (ins AnySignlessIntegerOrIndex:$lowerBound,
                       AnySignlessIntegerOrIndex:$upperBound,
                       AnySignlessIntegerOrIndex:$step,
                       Variadic<AnyType>:$initArgs);
  let results = (outs Variadic<AnyType>:$results);
  let regions = (region SizedRegion<1>:$region);

  let skipDefaultBuilders = 1;
  let builders = [
    OpBuilder<(ins "Value":$lowerBound, "Value":$upperBound, "Value":$step,
      CArg<"ValueRange", "std::nullopt">:$iterArgs,
      CArg<"function_ref<void(OpBuilder &, Location, Value, ValueRange)>",
           "nullptr">)>
  ];

  let extraClassDeclaration = [{
    using BodyBuilderFn =
        function_ref<void(OpBuilder &, Location, Value, ValueRange)>;

    Value getInductionVar() { return getBody()->getArgument(0); }

    /// Return the `index`-th region iteration argument.
    BlockArgument getRegionIterArg(unsigned index) {
      assert(index < getNumRegionIterArgs() &&
        "expected an index less than the number of region iter args");
      return getBody()->getArguments().drop_front(getNumInductionVars())[index];
    }

    void setLowerBound(Value bound) { getOperation()->setOperand(0, bound); }
    void setUpperBound(Value bound) { getOperation()->setOperand(1, bound); }
    void setStep(Value step) { getOperation()->setOperand(2, step); }

    /// Number of induction variables, always 1 for scf::ForOp.
    unsigned getNumInductionVars() { return 1; }
    /// Number of region arguments for loop-carried values
    unsigned getNumRegionIterArgs() {
      return getBody()->getNumArguments() - getNumInductionVars();
    }
    /// Number of operands controlling the loop: lb, ub, step
    unsigned getNumControlOperands() { return 3; }

    /// Returns the step as an `APInt` if it is constant.
    std::optional<APInt> getConstantStep();

    /// Interface method for ConditionallySpeculatable.
    Speculation::Speculatability getSpeculatability();
  }];

  let hasCanonicalizer = 1;
  let hasCustomAssemblyFormat = 1;
  let hasVerifier = 1;
  let hasRegionVerifier = 1;
}

// SCFExt IfOp
def SCFExt_IfOp : SCFExt_Op<"if", [DeclareOpInterfaceMethods<RegionBranchOpInterface, [
    "getNumRegionInvocations", "getRegionInvocationBounds",
    "getEntrySuccessorRegions"]>,
    InferTypeOpAdaptor, SingleBlockImplicitTerminator<"scf_ext::SCFExt_YieldOp">,
    RecursiveMemoryEffects, NoRegionArguments]> {
  let summary = "if-then-else operation";
  let description = [{
    The `scf_ext.if` operation represents an if-then-else construct for
    conditionally executing two regions of code. The operand to an if operation
    is a boolean value. For example:

    ```mlir
    scf_ext.if %b  {
      ...
    } else {
      ...
    }
    ```

    `scf_ext.if` may also produce results. Which values are returned depends on which execution path is taken.

    Example:

    ```mlir
    %x, %y = scf_ext.if %b -> (f32, f32) {
      %x_true = ...
      %y_true = ...
      scf.yield %x_true, %y_true : f32, f32
    } else {
      %x_false = ...
      %y_false = ...
      scf.yield %x_false, %y_false : f32, f32
    }
    ```

    The "then" region has exactly 1 block. The "else" region may have 0 or 1 block. In case the `scf_ext.if` produces results, the "else" region must also have exactly 1 block.

    The blocks are always terminated with `scf_ext.yield`. If `scf_ext.if` defines no values, the `scf_ext.yield` can be left out, and will be inserted implicitly.
    Otherwise, it must be explicit.

    Example:

    ```mlir
    scf_ext.if %b  {
      ...
    }
    ```

    The types of the yielded values must match the result types of the
    `scf_ext.if`.
  }];
  let arguments = (ins I1:$condition);
  let results = (outs Variadic<AnyType>:$results);
  let regions = (region SizedRegion<1>:$thenRegion,
                        MaxSizedRegion<1>:$elseRegion);

  let skipDefaultBuilders = 1;
  let builders = [
    OpBuilder<(ins "TypeRange":$resultTypes, "Value":$cond)>,
    OpBuilder<(ins "TypeRange":$resultTypes, "Value":$cond,
      "bool":$addThenBlock, "bool":$addElseBlock)>,
    OpBuilder<(ins "Value":$cond, "bool":$withElseRegion)>,
    OpBuilder<(ins "TypeRange":$resultTypes, "Value":$cond,
      "bool":$withElseRegion)>,
    OpBuilder<(ins "Value":$cond,
      CArg<"function_ref<void(OpBuilder &, Location)>",
           "buildTerminatedBody">:$thenBuilder,
      CArg<"function_ref<void(OpBuilder &, Location)>",
           "nullptr">:$elseBuilder)>,
  ];

  let extraClassDeclaration = [{
    OpBuilder getThenBodyBuilder(OpBuilder::Listener *listener = nullptr) {
      Block* body = getBody(0);
      return getResults().empty() ? OpBuilder::atBlockTerminator(body, listener)
                                  : OpBuilder::atBlockEnd(body, listener);
    }
    OpBuilder getElseBodyBuilder(OpBuilder::Listener *listener = nullptr) {
      Block* body = getBody(1);
      return getResults().empty() ? OpBuilder::atBlockTerminator(body, listener)
                                  : OpBuilder::atBlockEnd(body, listener);
    }
    Block* thenBlock();
    YieldOp thenYield();
    Block* elseBlock();
    YieldOp elseYield();
  }];
  let hasFolder = 1;
  let hasCanonicalizer = 1;
  let hasCustomAssemblyFormat = 1;
  let hasVerifier = 1;
}


// SCFExt YieldOp
def SCFExt_YieldOp : SCFExt_Op<"yield", [Pure, ReturnLike, Terminator,
    ParentOneOf<["SCFExt_ForOp", "SCFExt_IfOp"]>]> {
  let summary = "loop yield and termination operation";
  let description = [{
    "scf.yield" yields an SSA value from the SCF dialect op region and
    terminates the regions. The semantics of how the values are yielded is defined by the parent operation.
    If "scf.yield" has any operands, the operands must match the parent operation's results.
    If the parent operation defines no values, then the "scf.yield" may be left out in the custom syntax and the builders will insert one implicitly.
    Otherwise, it has to be present in the syntax to indicate which values are yielded.
  }];

  let arguments = (ins Variadic<AnyType>:$results);
  let builders = [OpBuilder<(ins), [{ /* nothing to do */ }]>];

  let assemblyFormat =
      [{  attr-dict ($results^ `:` type($results))? }];
}

#endif  // LIB_DIALECT_SCFEXT_IR_SCFEXTOPS_TD_

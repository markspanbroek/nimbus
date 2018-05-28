# Nimbus
# Copyright (c) 2018 Status Research & Development GmbH
# Licensed under either of
#  * Apache License, version 2.0, ([LICENSE-APACHE](LICENSE-APACHE) or http://www.apache.org/licenses/LICENSE-2.0)
#  * MIT license ([LICENSE-MIT](LICENSE-MIT) or http://opensource.org/licenses/MIT)
# at your option. This file may not be copied, modified, or distributed except according to those terms.

import
  tables,
  constants, vm_state,
  opcode_values, stint,
  vm / [code_stream, memory, stack],
  ./logging

type
  BaseComputation* = ref object of RootObj
    # The execution computation
    vmState*:               BaseVMState
    msg*:                   Message
    memory*:                Memory
    stack*:                 Stack
    gasMeter*:              GasMeter
    code*:                  CodeStream
    children*:              seq[BaseComputation]
    rawOutput*:             string
    returnData*:            string
    error*:                 Error
    logEntries*:            seq[(string, seq[UInt256], string)]
    shouldEraseReturnData*: bool
    accountsToDelete*:      Table[string, string]
    opcodes*:               Table[Op, Opcode] # TODO array[Op, Opcode]
    precompiles*:           Table[string, Opcode]
    gasCosts*:              GasCosts # TODO separate opcode processing and gas computation

  Error* = ref object
    info*:                  string
    burnsGas*:              bool
    erasesReturnData*:      bool

  Opcode* = ref object of RootObj
    kind*: Op
    #of VARIABLE_GAS_COST_OPS:
    #  gasCostHandler*: proc(computation: var BaseComputation): UInt256
    ## so, we could have special logic that separates all gas cost calculations
    ## from actual opcode execution
    ## that's what parity does:
    ##   it uses the peek methods of the stack and calculates the cost
    ##   then it actually pops/pushes stuff in exec
    ## I followed the py-evm approach which does that in opcode logic
    gasCostKind*: GasCostKind
    runLogic*:  proc(computation: var BaseComputation)

  GasInt* = int64
    ## Type alias used for gas computation
    # For reference - https://github.com/status-im/nimbus/issues/35#issuecomment-391726518

  GasMeter* = ref object
    logger*: Logger
    gasRefunded*: GasInt
    startGas*: GasInt
    gasRemaining*: GasInt

  GasCostKind* = enum
    GasZero
    GasBase
    GasVeryLow
    GasLow
    GasMid
    GasHigh
    GasSload
    GasJumpDest
    GasSset
    GasSreset
    GasExtCode
    GasCoinbase
    GasSelfDestruct
    GasInHandler
    GasRefundSclear

    GasBalance
    GasCall
    GasExp
    GasSHA3

  GasCosts* = array[GasCostKind, GasInt]

  Message* = ref object
    # A message for VM computation

    # depth = None

    # code = None
    # codeAddress = None

    # createAddress = None

    # shouldTransferValue = None
    # isStatic = None

    # logger = logging.getLogger("evm.vm.message.Message")

    gas*:                     GasInt
    gasPrice*:                GasInt
    to*:                      string
    sender*:                  string
    value*:                   UInt256
    data*:                    seq[byte]
    code*:                    string
    internalOrigin*:          string
    internalCodeAddress*:     string
    depth*:                   int
    internalStorageAddress*:  string
    shouldTransferValue*:     bool
    isStatic*:                bool
    isCreate*:                bool

  MessageOptions* = ref object
    origin*:                  string
    depth*:                   int
    createAddress*:           string
    codeAddress*:             string
    shouldTransferValue*:     bool
    isStatic*:                bool
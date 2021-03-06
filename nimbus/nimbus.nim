# Nimbus
# Copyright (c) 2018 Status Research & Development GmbH
# Licensed under either of
#  * Apache License, version 2.0, ([LICENSE-APACHE](LICENSE-APACHE))
#  * MIT license ([LICENSE-MIT](LICENSE-MIT))
# at your option.
# This file may not be copied, modified, or distributed except according to
# those terms.

import strutils, net
import asyncdispatch2, rpcserver, eth_p2p, eth_keys
import config, rpc/common, rpc/p2p

## TODO:
## * No IPv6 support
## * No multiple bind addresses support
## * No database support

when not defined(windows):
  from posix import SIGINT, SIGTERM

type
  NimbusState = enum
    Starting, Running, Stopping, Stopped

  NimbusObject = ref object
    rpcServer*: RpcServer
    p2pServer*: P2PServer
    state*: NimbusState

proc start(): NimbusObject =
  var nimbus = NimbusObject()
  var conf = getConfiguration()

  ## Creating RPC Server
  if RpcFlags.Enabled in conf.rpc.flags:
    nimbus.rpcServer = newRpcServer(conf.rpc.binds)
    setupCommonRpc(nimbus.rpcServer)

  ## Creating P2P Server
  if conf.net.nodekey.isZeroKey():
    conf.net.nodekey = newPrivateKey()

  var keypair: KeyPair
  keypair.seckey = conf.net.nodekey
  keypair.pubkey = conf.net.nodekey.getPublicKey()

  var address: Address
  address.ip = parseIpAddress("0.0.0.0")
  address.tcpPort = Port(conf.net.bindPort)
  address.udpPort = Port(conf.net.discPort)

  nimbus.p2pServer = newP2PServer(keypair, address, nil, conf.net.bootNodes,
                                  conf.net.ident, conf.net.networkId)

  if RpcFlags.Enabled in conf.rpc.flags:
    setupP2PRpc(nimbus.p2pServer, nimbus.rpcServer)

  ## Starting servers
  nimbus.state = Starting
  if RpcFlags.Enabled in conf.rpc.flags:
    nimbus.rpcServer.rpc("admin_quit") do() -> string:
      nimbus.state = Stopping
      result = "EXITING"
    nimbus.rpcServer.start()
  nimbus.p2pServer.start()
  nimbus.state = Running
  result = nimbus

proc stop*(nimbus: NimbusObject) {.async.} =
  echo "Graceful shutdown"
  nimbus.rpcServer.stop()

proc process*(nimbus: NimbusObject) =
  if nimbus.state == Running:
    when not defined(windows):
      proc signalBreak(udata: pointer) =
        nimbus.state = Stopping
      # Adding SIGINT, SIGTERM handlers
      discard addSignal(SIGINT, signalBreak)
      discard addSignal(SIGTERM, signalBreak)

    # Main loop
    while nimbus.state == Running:
      poll()

    # Stop loop
    waitFor nimbus.stop()

when isMainModule:
  var message: string

  ## Pring Nimbus header
  echo NimbusHeader

  ## Processing command line arguments
  if processArguments(message) != ConfigStatus.Success:
    echo message
    quit(QuitFailure)
  else:
    if len(message) > 0:
      echo message
      quit(QuitSuccess)

  var nimbus = start()
  nimbus.process()

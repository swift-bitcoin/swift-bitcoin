# ``Bitcoin``

Pure-Swift Bitcoin client implementation with full node capabilities.

## Overview

Swift Bitcoin is comprised of several core components. The main entry-point is the `Bitcoin` framework which can be easily integrated into virtually all types of Swift projects.

### Bitcoin Node

The [Bitcoin Node (bcnode)](https://swift-bitcoin.github.io/docc/bcnode/documentation/bcnode/) command-line tool is used to launch a Bitcoin RPC server and peer-to-peer network client.

### Bitcoin Utility

The [Bitcoin Utility (bcutil)](https://swift-bitcoin.github.io/docc/bcutil/documentation/bcutil/) command-line tool can be used to perform off-chain wallet operations as well as controlling a running node instance via RPC.

### Libraries

- BitcoinTransport - ``NodeService``
- BitcoinBlockchain - ``BitcoinService``, ``BlockHeader``
- BitcoinWallet - ``Wallet``
- BitcoinBase - ``BitcoinTransaction``, ``BitcoinScript``. 
- BitcoinCrypto - ``RIPEMD160``, ``sha256(_:)``, ``signSchnorr(msg:secretKey:tweak:aux:)``

## Topics

### Essentials

- <doc:GettingStarted>
- ``BitcoinTransaction``
- ``BitcoinScript``
- ``BlockHeader``
- ``BitcoinService``
- ``NodeService``

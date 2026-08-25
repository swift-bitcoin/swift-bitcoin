# Signet

Run a node on a signet network, whether it be the default or one with a custom challenge.

## Overview

Signet networks are global test networks where coins have no value. Unlike test networks where anyone can mine, signets require blocks to be signed by miners who hold the required private keys.

## Experiments

### Connecting two local Bitcoin Core signet instances

#### Download Bitcoin Core

Get a binary distribution packaged as `.tar.gz` from [https://bitcoincore.org/en/download/]. On Mac, make sure you don't install the GUI-only version BitcoinQT.

For instance, the link for version 31.1 is:

https://bitcoincore.org/bin/bitcoin-core-31.1/bitcoin-31.1-arm64-apple-darwin.tar.gz


#### Run a default signet node


First run (full sync, up to 100GB of free storage required as of September 2026):

    ./bin/bitcoind -signet

You may interrupt the sync process by stopping the node:

    ./bin/bitcoin-cli -signet stop

Another way is to ask the node to stop syncing at a given height:

    ./bin/bitcoind -signet -stopatheight=182605

Check disk usage (Mac)

    du -h ~/Library/Application\ Support/Bitcoin/signet

Run again without outward connectivity and enabling inward connectivity. Force the node to communicate with version 1 wire protocol. Disable minimum chain work check.

    ./bin/bitcoind -signet -v2transport=0 -connect=0 -listen=1 -minimumchainwork=0

#### Connect a second Core instance

Now for the second instance, specify a custom data dir and custom ports to avoid collision with the already running instance. Ask to connect to the first instance on the same host.

    mkdir bitcoin-data-2
    ./bin/bitcoind -signet -datadir=$PWD/bitcoin-data-2 -rpcport=38335 -port=38336 -v2transport=0 -minimumchainwork=0 -connect=localhost

To query the second instance:

    ./bin/bitcoin-cli -signet -datadir=$PWD/bitcoin-data-2 -rpcport=38335 stop

#### Connect a Swift Bitcoin instance

Launch a node and have it connect to a Core instance. Make sure you stop the second Core instance first to reuse port numbers.

    bcnode start --network signet --connect 127.0.0.1 --auto-connect false --rpc-port 38335

To disable minimum chain-work and assume valid settings pass the default signet challenge explicitly (the node will interpret it as a custom challenge and disable minimum chain-work and assume valid).

    bcnode start --network signet --signet-challenge 512103ad5e0edad18cb1f0fc0d28a3d4f1f3e445640337489abb10404f2d1e086be430210359ef5021964fe22d6f8e05b2463c9540ce96883fe3b278760f048f5189f2e6c452ae --connect 127.0.0.1 --auto-connect false --rpc-port 38335

To manually connect first start without the `connect` option.

    bcnode start --network signet --auto-connect false --rpc-port 38335

Then ask to connect with Bitcoin Utility. By defauly it will connect to `localhost` using the default port for the daemon's network (signet). The `port` option here refers to the RPC port of the running node.

    bcutil node connect --port 38335

# Testnet

Swift Bitcoin supports the `testnet4` chain.

## Overview

To sync the testnet chain we will use a Bitcoin Core instance as a proxy.

Note: Swift Bitcoin only supports Testnet 4 which is usually referred to as `testnet`. Bitcoin Core explicitly specifies `testnet4` to separate from the default Testnet 3 chain.

## Containers

A container tool like Docker can help us simulate a network of nodes.

### Swift Bitcoin Container

To run a daemon instance in a container named _Alice_ we can specify the development tree as a volume:

```sh
docker run --rm -it --network bitcoin-test --name alice -v $PWD:/opt/swift-bitcoin swift
```

Inside the container prompt we can use `swift run` to start `bcnode`:

```sh
cd /opt/swift-bitcoin
swift run bcnode -n testnet
```

To check the node's status open another terminal and connect to the running container:

```sh
docker exec -it alice bash
```

Inside the `docker exec` prompt we can use `bcutil` to start the peer-to-peer service and check the node's status:

```sh
cd /opt/swift-bitcoin
swift run bcutil -n testnet start-p2p
swift run bcutil -n testnet status
```

### Bitcoin Core Container

Assuming you have `bitcoind` and `bitcoin-cli` built as docker images – see <doc:Building> for instructions – we can launch an instance named _Carol_ on a separate terminal:

```sh
docker run --name carol --rm -it --network bitcoin-test -v /bitcoin_auth/ -chain=testnet4 -disablewallet -txindex -server -rpcallowip=0.0.0.0/0 -rpcbind=0.0.0.0 -rpccookiefile=/bitcoin_auth/cookie
```

With the command above are disabling wallet functionality and enabling the transaction index.

We are also using a custom volume to store the authentication cookie which we read from when running the `bitcoin-cli` image.

On a separate terminal create an alias for `bitcoin-cli`:

```sh
alias bitcoin-cli="docker run --rm --network bitcoin-test --volumes-from carol bitcoin-cli -testnet4 -rpcconnect=carol  -rpccookiefile=/bitcoin_auth/cookie"
prompt="carol: "
```

After that we can use the alias:

```sh
bitcoin-cli -getinfo
```

### Connecting both instances

To connect from Bitcoin Core to Swift Bitcoin use `bitcoin-cli addnode alice onetry`.

Verify connection on Carol's node with `bitcoin-cli getpeerinfo`.

From Alice's terminal you can connect to Carol's Bitcoin Core instance using `bcutil -n testnet connect -i carol`. But make sure `connect=0` was not used when launching the Bitcoin Core instance – keep reading to understand why we may need to prevent automatic connections.

## Partial sync

During development we might not want to sync the entire testnet blockchain. For this we can limit the number of blocks and connectivity in Bitcoin Core. We'll do this in two steps.

The first time, an additional `-stopatheight=16` is be added to only download up to block 16.

```sh
docker run --name carol --rm -it --network bitcoin-test -v /bitcoin_auth/ -v bitcoin-test:/root/.bitcoin bitcoind -chain=testnet4 -disablewallet -txindex -server -debug=net -stopatheight=16 -rpcallowip=0.0.0.0/0 -rpcbind=0.0.0.0 -rpccookiefile=/bitcoin_auth/cookie
```

We are also adding a volume to keep the downloaded block data between launches.

Once the instance stops automatically after reaching the block limit we'll remove the limit and re-launch with `-connect=0` to prevent the node from downloading further blocks.

```sh
docker run --name carol --rm -it --network bitcoin-test -v /bitcoin_auth/ -v bitcoin-test:/root/.bitcoin bitcoind -chain=testnet4 -disablewallet -txindex -server -debug=net -connect=0 -v2transport=0 -minimumchainwork=0x0000000000000000000000000000000000000000000000000000000000000000 -rpcallowip=0.0.0.0/0 -rpcbind=0.0.0.0 -rpccookiefile=/bitcoin_auth/cookie
```

Additionally we are removing the default chainwork limit, otherwise the node will not serve blocks to connecting peers.

We are also disabling version 2 transport as Swift Bitcoin does not support it.

After this we can connect Carol's node to Alice's as usual with `bitcoin-cli addnode alice onetry`. 

To check that the synchronization was successful check Alice's blockchain information:

`swift run bcutil -n testnet get-blockchain-info`

### Clear blockchain data

To reset the blockchain data simply remove the Docker volume:

```sh
docker volume rm bitcoin-test
```

### Other options

The configuration option `assumevalid=0` can also be used to force the node to verify all nodes. This is safe to do when only downloading an initial portion of the chain.

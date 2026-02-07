# Mainnet Development

After working with regtest, testnet and signet sometimes we may need to check something on mainnet. Take precautions when using real bitcoin on an experimental implementation. One of these precautions is to only use very small amounts when sending.

When possible use a production Bitcoin Core instance to sync and validate against.

## Notes

Here's some notes of how to setup Swift Bitcoin along side with Bitcoin Core for development work on mainnet.

### Useful Settings

Using Jameson Lopp's [configurator](https://jlopp.github.io/bitcoin-core-config-generator/) we can explore some useful settings / command-line arguments.

For rebuilding indices from previous or internal block data use `loadblock`, `reindex` and `reindex-chainstate`.

```
# [core]
# Imports blocks from external blk000??.dat file on startup. This option can be set multiple times with different file values.
loadblock=0
# Reindex chain state from the currently indexed blocks. WARNING: very slow!
reindex-chainstate=1
# Rebuild chain state and block index from the blk*.dat files on disk. WARNING: very slow!
reindex=1

```

### Docker

Use Docker to launch a containerized `bitcoind` instance.

Disable block file obfuscation with the `blocksxor` option:

```
docker run --name carol --rm -it --network bitcoin -v /bitcoin_auth/ -v bitcoin-test:/root/.bitcoin bitcoind -blocksxor=0 -disablewallet -txindex -server -rpcallowip=0.0.0.0/0 -rpcbind=0.0.0.0 -rpccookiefile=/bitcoin_auth/cookie
```

Stop at a specific height with `stopatheight`:

```
docker run --name carol --rm -it --network bitcoin-test -v /bitcoin_auth/ -v bitcoin-test:/root/.bitcoin bitcoind -chain=testnet4 -disablewallet -txindex -server -debug=net -stopatheight=119100 -rpcallowip=0.0.0.0/0 -rpcbind=0.0.0.0 -rpccookiefile=/bitcoin_auth/cookie
```

Block height `119100` is just enough to fill up the first block file `blk00000.dat`.

Disable V2 transport protocol using option `v2transport` or prevent automatic connections altogether with `connect`:

```
docker run --name carol --rm -it --network bitcoin -v /bitcoin_auth/ -v bitcoin:/root/.bitcoin -p 48333:48333 bitcoind -reindex -blocksxor=0 -disablewallet -txindex -server -debug=net -connect=0 -v2transport=0 -minimumchainwork=0x0000000000000000000000000000000000000000000000000000000000000000 -rpcallowip=0.0.0.0/0 -rpcbind=0.0.0.0 -rpccookiefile=/bitcoin_auth/cookie
```

Create an alias for a dockerized `bitcoin-cli`:

```
alias bitcoin-cli="docker run --rm --network bitcoin --volumes-from carol bitcoin-cli -rpcconnect=carol  -rpccookiefile=/bitcoin_auth/cookie"


```

Mount the volume with Alpine Linux so we can extract a copy of the first block file:

```
docker run --name bitcoin-volume --rm -it -v bitcoin:/bitcoin alpine
docker cp bitcoin-volume:/bitcoin/blocks/blk00000.dat .
```

Relaunch with just `blocks/blk00000.dat` in place and `-reindex -blocksxor=0`:

```
docker run --name carol --rm -it --network bitcoin -v /bitcoin_auth/ -v bitcoin:/root/.bitcoin -p 48333:48333 bitcoind -reindex -blocksxor=0 -disablewallet -txindex -server -debug=net -connect=0 -v2transport=0 -minimumchainwork=0x0000000000000000000000000000000000000000000000000000000000000000 -rpcallowip=0.0.0.0/0 -rpcbind=0.0.0.0 -rpccookiefile=/bitcoin_auth/cookie
```

After reindexing with only the first block file:

```
bitcoin-cli -getinfo
Chain: main
Blocks: 119100
Headers: 119100
```

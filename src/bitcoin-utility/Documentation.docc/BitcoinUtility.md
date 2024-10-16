# ``BitcoinUtility``

@Metadata {
    @DisplayName("Bitcoin Utility (bcutil)")
    @TitleHeading("Swift Bitcoin Tool")
}

Use the `bcutil` command control a running Bitcoin node instance or perform off-chain operations.

## Overview

> Swift Bitcoin: This tool is part of the [Swift Bitcoin](https://swift-bitcoin.github.io/docc/documentation/bitcoin/) suite.

We can use `bcutil` to perform both offline operations as well as issuing RPC commands to a runing `bcnode`.

The following example shows how we can start from an empty blockchain, generate one empty block and then create, sign, submit to the mempool and mine a transaction.

```sh

# Generate a new secret key

bcutil ec-new
24516525843cb692a1ccb18ecd1b3b6c71352614d3aef455a007592910acdabd


# Derive a public key from the secret key 

bcutil ec-to-public 24516525843cb692a1ccb18ecd1b3b6c71352614d3aef455a007592910acdabd
029a3865b2488e2fee75336d1048c1d0795a088368a0caa4adc076425c90227bc3


# Generate a block with the reward going to our public key

bcutil generate-to 029a3865b2488e2fee75336d1048c1d0795a088368a0caa4adc076425c90227bc3
3b1517aaf42737c482b489b15cdf80b57f9f517025ab7be65d104f8fecc1345a


# Check our new block's coinbase transaction

bcutil get-block 3b1517aaf42737c482b489b15cdf80b57f9f517025ab7be65d104f8fecc1345a
{
  "identifier" : "3b1517aaf42737c482b489b15cdf80b57f9f517025ab7be65d104f8fecc1345a",
  "previous" : "0f9188f13cb7b2c71f2a335e3a4fc328bf5beb436012afca590b1a11466e2206",
  "transactions" : [
    "71847446d61f87f01ea98e4c32f3ecd7a509cdb912c04a13a4b20736af5a0d49"
  ]
}


# Find out what the raw first output in our funding transaction is. We will need it later to sign our spending transaction.

bcutil get-transaction 71847446d61f87f01ea98e4c32f3ecd7a509cdb912c04a13a4b20736af5a0d49
{
  "identifier" : "71847446d61f87f01ea98e4c32f3ecd7a509cdb912c04a13a4b20736af5a0d49",
  "inputs" : [
    {
      "output" : 4294967295,
      "transaction" : "0000000000000000000000000000000000000000000000000000000000000000"
    }
  ],
  "outputs" : [
    {
      "amount" : 5000000000,
      "raw" : "00f2052a010000001976a914df4bdfc1f4a0eb9d08a22598c69a15c9989adc8688ac",
      "script" : "76a914df4bdfc1f4a0eb9d08a22598c69a15c9989adc8688ac"
    },
    {
      "amount" : 0,
      "raw" : "0000000000000000266a24aa21a9ede2f61c3f71d1defd3fa999dfa36953755c690689799962b48bebd836974e8cf9",
      "script" : "6a24aa21a9ede2f61c3f71d1defd3fa999dfa36953755c690689799962b48bebd836974e8cf9"
    }
  ]
}


# Get an address for our previously derived public key

bcutil ec-to-address 029a3865b2488e2fee75336d1048c1d0795a088368a0caa4adc076425c90227bc3
1MMgabnpMVKTnYXwJfupDJRpWNJmUay8cP


# Create a new transaction spending 100 sats from that coinbase transaction into our generated address

bcutil create-transaction -i 71847446d61f87f01ea98e4c32f3ecd7a509cdb912c04a13a4b20736af5a0d49 -o 0 -a 1MMgabnpMVKTnYXwJfupDJRpWNJmUay8cP -s 100
0100000001490d5aaf3607b2a4134ac012b9cd09a5d7ecf3324c8ea91ef0871fd6467484710000000000ffffffff0164000000000000001976a914df4bdfc1f4a0eb9d08a22598c69a15c9989adc8688ac00000000


# Now sign the transaction's only input using the secret key. We are providing the raw output that we are spending. 

bcutil sign-transaction -i 0 -p 00f2052a010000001976a914df4bdfc1f4a0eb9d08a22598c69a15c9989adc8688ac -s 24516525843cb692a1ccb18ecd1b3b6c71352614d3aef455a007592910acdabd 0100000001490d5aaf3607b2a4134ac012b9cd09a5d7ecf3324c8ea91ef0871fd6467484710000000000ffffffff0164000000000000001976a914df4bdfc1f4a0eb9d08a22598c69a15c9989adc8688ac00000000

0100000001490d5aaf3607b2a4134ac012b9cd09a5d7ecf3324c8ea91ef0871fd646748471000000006a47304402207ff327117905eddf0501d835a6653a006aaa41deee0ad1b6b0c3e51b8c831dca022011c848177a5c7b527476f0f28edc119233dbaa6729570da9f8a747bcd678c3a20121029a3865b2488e2fee75336d1048c1d0795a088368a0caa4adc076425c90227bc3ffffffff0164000000000000001976a914df4bdfc1f4a0eb9d08a22598c69a15c9989adc8688ac00000000


# Verify our mempool is empty before sending the transaction

bcutil get-mempool
{
  "size" : 0,
  "transactions" : []
}


# Send the signed transaction

bcutil send-transaction 0100000001490d5aaf3607b2a4134ac012b9cd09a5d7ecf3324c8ea91ef0871fd646748471000000006a47304402207ff327117905eddf0501d835a6653a006aaa41deee0ad1b6b0c3e51b8c831dca022011c848177a5c7b527476f0f28edc119233dbaa6729570da9f8a747bcd678c3a20121029a3865b2488e2fee75336d1048c1d0795a088368a0caa4adc076425c90227bc3ffffffff0164000000000000001976a914df4bdfc1f4a0eb9d08a22598c69a15c9989adc8688ac00000000


# Verify that the transaction has been accepted into the mempool

bcutil get-mempool
{
  "size" : 1,
  "transactions" : [
    "f6071f3eec4b4484994501d353d65e47d8384bd891e08500b5d54856e437ea13"
  ]
}


# Generate another block

bcutil generate-to 03156c29378949152f270170589e4bb3e006bf57d908f7a173edf9fa2956cae388 
328b649efac1dacf329aeb86d59ef99e2e2b2578b1137b3da1ef94c3c0535708


# Check that the mempool has been emptied again

bcutil get-mempool
{
  "size" : 0,
  "transactions" : []
}


# Check that the transaction is now part of the latest block

bcutil get-block 328b649efac1dacf329aeb86d59ef99e2e2b2578b1137b3da1ef94c3c0535708
{
  "identifier" : "328b649efac1dacf329aeb86d59ef99e2e2b2578b1137b3da1ef94c3c0535708",
  "previous" : "3b1517aaf42737c482b489b15cdf80b57f9f517025ab7be65d104f8fecc1345a",
  "transactions" : [
    "218826825d34db191f89e3079f394dfdf7c227017e6423be17a78d7c5d40ba5c",
    "f6071f3eec4b4484994501d353d65e47d8384bd891e08500b5d54856e437ea13"
  ]
}
```

Use `--help` to find out about other subcommands and general usage.

## Topics

### Essentials

- ``Node``

## See Also

- [Swift Bitcoin "Umbrella" Library][swiftbitcoin]
- [Crypto Library][crypto]
- [Base Library][base]
- [Wallet Library][wallet]
- [Blockchain Library][blockchain]
- [Transport Library][transport]
- [RPC Library][rpc]
- [Bitcoin Node (bcnode) Command][bcnode]

<!-- links -->

[swiftbitcoin]: https://swift-bitcoin.github.io/docc/documentation/bitcoin/
[crypto]: https://swift-bitcoin.github.io/docc/crypto/documentation/bitcoincrypto/
[base]: https://swift-bitcoin.github.io/docc/base/documentation/bitcoinbase/
[wallet]: https://swift-bitcoin.github.io/docc/wallet/documentation/bitcoinwallet/
[blockchain]: https://swift-bitcoin.github.io/docc/blockchain/documentation/bitcoinblockchain/
[transport]: https://swift-bitcoin.github.io/docc/transport/documentation/bitcointransport/
[rpc]: https://swift-bitcoin.github.io/docc/rpc/documentation/bitcoinrpc/
[bcnode]: https://swift-bitcoin.github.io/docc/bcnode/documentation/bitcoinnode/

# Blockchain Service Design

The ``BlockchainService`` actor encapsulates logic for blockchain, mempool and coins (UTXO set). This includes validation, processing, indexing and storage.

## Blocks

The blockchain keeps a copy of each header and block that's been at least partially validated.

### Headers

When a header is received during the first stage of the headers-first synchronization it is expected to come in sequential order. Once the header has been proven valid, it is indexed.

A reference to the best header is kept at the actor level.

### Block transactions

Once transactions have been received for a given block, sanity checks are performed. The header must already exist in the index. The Merkle root of transactions is verified and the index is updated with the _merkle_ verification status.

Even before the transactions are verified, the block is stored to disk without any undo information.

### Block undo

If a block is successfully verified and connected to the rest of the chain. It's undo information is calculated and stored in a `rev#####.dat` file which has the same count as the block's file. The internal order of the file and offsets will be different however.

Undo information consists of all coins spent by the block so that they can be added back to the UTXO set if the block is reverted.

### Index

Blocks are indexed in an LMDB database using their ID. The index contains the block header, it's location on disk, the location for the undo information, its current validation status, its height in the blockchain and the accumulated chain work use to determine the longest chain. An additional index by height is also kept.

## Transactions

## Mempool
## Mining (Block generation)
## Relay
